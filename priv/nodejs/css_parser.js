/**
 * CSS Parser using `css` library
 *
 * Parses CSS into structured rules for wireframe editor.
 * Similar architecture to js_parser.js.
 *
 * Input: CSS string
 * Output: { rules: { selector: declarations, ... } }
 */

const css = require('css');

/**
 * Parse CSS string into structured rules
 * @param {string} cssContent - The CSS content to parse
 * @returns {object} - { rules: { selector: declarations, ... } }
 */
function parseCSS(cssContent) {
  try {
    const ast = css.parse(cssContent, { silent: false });

    const rules = {};

    // Extract rules from stylesheet
    if (ast.stylesheet && ast.stylesheet.rules) {
      for (const rule of ast.stylesheet.rules) {
        if (rule.type === 'rule') {
          // Standard CSS rule with selectors and declarations
          const ruleData = extractRule(rule);
          if (ruleData) {
            // Merge declarations if selector already exists (handles duplicate selectors)
            if (rules[ruleData.selector]) {
              Object.assign(rules[ruleData.selector], ruleData.declarations);
            } else {
              rules[ruleData.selector] = ruleData.declarations;
            }
          }
        }
        // Ignore @media, @keyframes, etc. for MVP
        // Can add support later if needed
      }
    }

    return { rules };

  } catch (error) {
    throw new Error(`CSS parsing failed: ${error.message}`);
  }
}

/**
 * Extract a single CSS rule
 * @param {object} rule - AST rule node
 * @returns {object} - {selector, declarations}
 */
function extractRule(rule) {
  if (!rule.selectors || rule.selectors.length === 0) {
    return null;
  }

  // Join multiple selectors with comma (e.g., "h1, h2, h3")
  const selector = rule.selectors.join(', ');

  // Extract declarations as key-value pairs
  const declarations = {};

  if (rule.declarations) {
    for (const decl of rule.declarations) {
      if (decl.type === 'declaration' && decl.property && decl.value) {
        declarations[decl.property] = decl.value;
      }
    }
  }

  return {
    selector,
    declarations
  };
}

// Export for use in NodeJS module
module.exports = { parseCSS };

// CLI interface for testing
if (require.main === module) {
  const cssContent = process.argv[2] || '';

  try {
    const result = parseCSS(cssContent);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
