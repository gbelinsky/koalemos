const esprima = require('esprima');
const escodegen = require('escodegen');

/**
 * Parse JavaScript code and extract window.* declarations and event handlers.
 * Uses AST to generate clean remaining code.
 * Returns: {variables, functions, handlers, initScript}
 */
function parseJavaScript(code) {
  try {
    const ast = esprima.parseScript(code, { loc: true, range: true });

    const variables = {};
    const functions = {};
    const handlers = {};
    const nodesToRemove = new Set();

    // Helper to extract handler code and parameters from a function node
    function extractHandlerInfo(handler) {
      if (handler.type === 'FunctionExpression' || handler.type === 'ArrowFunctionExpression') {
        // Extract parameter names
        const params = handler.params?.map(param => {
          if (param.type === 'Identifier') {
            return param.name;
          }
          // For complex params, use original source
          return code.substring(param.range[0], param.range[1]);
        }) || [];

        let bodyCode;
        if (handler.body.type === 'BlockStatement') {
          // Get the body content without the wrapping braces
          const bodyStart = handler.body.range[0] + 1; // Skip opening {
          const bodyEnd = handler.body.range[1] - 1;    // Skip closing }
          bodyCode = code.substring(bodyStart, bodyEnd).trim();
        } else {
          // Arrow function with expression body - need to add return
          const [bodyStart, bodyEnd] = handler.body.range;
          bodyCode = 'return ' + code.substring(bodyStart, bodyEnd) + ';';
        }

        return { params, bodyCode };
      }
      return null;
    }

    // Helper to check if a node is a handler we want to extract
    function isHandlerNode(node) {
      if (node?.type === 'ExpressionStatement' && node.expression?.type === 'CallExpression') {
        const callExpr = node.expression;

        if (callExpr.callee?.type === 'MemberExpression' &&
            callExpr.callee.property?.name === 'addEventListener' &&
            callExpr.arguments?.length >= 2) {

          const obj = callExpr.callee.object;
          if (obj?.type === 'CallExpression' &&
              obj.callee?.type === 'MemberExpression' &&
              obj.callee.object?.name === 'document' &&
              obj.callee.property?.name === 'getElementById' &&
              obj.arguments?.length === 1 &&
              obj.arguments[0]?.type === 'Literal') {
            return true;
          }
        }
      }
      return false;
    }

    // Helper to recursively walk AST, find handlers, and remove them
    function walkAndTransform(node) {
      if (!node || typeof node !== 'object') return node;

      // Extract handler if this is one
      if (isHandlerNode(node)) {
        const callExpr = node.expression;
        const obj = callExpr.callee.object;
        const elementId = obj.arguments[0].value;
        const eventType = callExpr.arguments[0]?.value;
        const handler = callExpr.arguments[1];

        const handlerInfo = extractHandlerInfo(handler);
        if (handlerInfo) {
          if (!handlers[elementId]) {
            handlers[elementId] = {};
          }
          // Store both params and body code
          handlers[elementId][eventType] = {
            params: handlerInfo.params,
            body: handlerInfo.bodyCode
          };
        }

        // Return null to signal this node should be removed
        return null;
      }

      // Recursively transform all properties
      for (const key in node) {
        if (key === 'range' || key === 'loc' || key === 'parent') continue;
        const value = node[key];

        if (Array.isArray(value)) {
          // Filter out null values (removed handler nodes)
          node[key] = value.map(walkAndTransform).filter(v => v !== null);
        } else if (value && typeof value === 'object') {
          const transformed = walkAndTransform(value);
          if (transformed === null) {
            delete node[key];
          } else {
            node[key] = transformed;
          }
        }
      }

      return node;
    }

    // Walk the AST to find declarations and handlers
    ast.body.forEach((node, index) => {
      // Extract window.* assignments
      if (node.type === 'ExpressionStatement' &&
          node.expression.type === 'AssignmentExpression' &&
          node.expression.left.type === 'MemberExpression' &&
          node.expression.left.object.name === 'window' &&
          node.expression.left.property.type === 'Identifier') {

        const name = node.expression.left.property.name;
        const right = node.expression.right;

        // Determine if it's a function or variable
        if (right.type === 'FunctionExpression' || right.type === 'ArrowFunctionExpression') {
          // Extract just the function value (without window.name =)
          const [valueStart, valueEnd] = right.range;
          const functionCode = code.substring(valueStart, valueEnd);
          functions[name] = functionCode;
        } else {
          // It's a variable - try to extract the value
          const [valueStart, valueEnd] = right.range;
          const valueCode = code.substring(valueStart, valueEnd);

          try {
            // Try to eval it as JSON
            const value = JSON.parse(valueCode);
            variables[name] = value;
          } catch (e) {
            // If it's not valid JSON, skip it
            console.error(`Could not parse value for ${name}: ${valueCode}`);
          }
        }

        // Mark this node for removal
        nodesToRemove.add(index);
      }

      // Extract top-level function declarations (function name() { ... })
      if (node.type === 'FunctionDeclaration' && node.id?.name) {
        const name = node.id.name;
        // Extract the full function code
        const [funcStart, funcEnd] = node.range;
        const functionCode = code.substring(funcStart, funcEnd);
        functions[name] = functionCode;

        // Mark this node for removal from init script
        nodesToRemove.add(index);
      }

    });

    // Transform the AST to remove handlers (this modifies the tree in place)
    walkAndTransform(ast);

    // Generate init script from remaining nodes (after handler removal)
    const remainingNodes = ast.body.filter((_, index) => !nodesToRemove.has(index));

    // Helper to check if a node is a DOMContentLoaded wrapper
    function isDOMContentLoadedWrapper(node) {
      return node.type === 'ExpressionStatement' &&
             node.expression?.type === 'CallExpression' &&
             node.expression.callee?.type === 'MemberExpression' &&
             node.expression.callee.object?.name === 'document' &&
             node.expression.callee.property?.name === 'addEventListener' &&
             node.expression.arguments?.length >= 2 &&
             node.expression.arguments[0]?.value === 'DOMContentLoaded';
    }

    // Helper to extract body from DOMContentLoaded wrapper
    function extractDOMContentLoadedBody(node) {
      const handler = node.expression.arguments[1];
      if ((handler.type === 'FunctionExpression' || handler.type === 'ArrowFunctionExpression') &&
          handler.body?.type === 'BlockStatement' &&
          handler.body.body) {
        return handler.body.body;
      }
      return null;
    }

    // Recursively unwrap ALL DOMContentLoaded wrappers to flatten the init script
    function unwrapAllDOMContentLoaded(nodes) {
      let hasChanges = true;
      let currentNodes = nodes;

      // Keep unwrapping until no more DOMContentLoaded wrappers found
      while (hasChanges) {
        hasChanges = false;
        const newNodes = [];

        currentNodes.forEach(node => {
          if (isDOMContentLoadedWrapper(node)) {
            const body = extractDOMContentLoadedBody(node);
            if (body) {
              // Unwrap: add the inner statements directly
              newNodes.push(...body);
              hasChanges = true;
            } else {
              // Can't unwrap, keep as-is
              newNodes.push(node);
            }
          } else {
            newNodes.push(node);
          }
        });

        currentNodes = newNodes;
      }

      return currentNodes;
    }

    // Unwrap all DOMContentLoaded wrappers recursively
    const unwrappedNodes = unwrapAllDOMContentLoaded(remainingNodes);

    const remainingAst = { ...ast, body: unwrappedNodes };

    let initScript = '';
    if (unwrappedNodes.length > 0) {
      try {
        initScript = escodegen.generate(remainingAst);
      } catch (e) {
        console.error('Error generating code:', e.message);
        initScript = '';
      }
    }

    return { variables, functions, handlers, initScript };
  } catch (error) {
    console.error('Parse error:', error.message);
    return { variables: {}, functions: {}, handlers: {}, initScript: '', error: error.message };
  }
}

module.exports = { parseJavaScript };
