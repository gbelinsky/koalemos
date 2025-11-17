# Koalemos Usage Guide

**Complete guide to using the Interactive Wireframe Editor**

---

## What is the Wireframe Editor?

The Wireframe Editor is Koalemos's flagship demo - an AI agent that helps you build HTML wireframes (UI prototypes) through natural conversation. Instead of manually writing HTML/CSS/JavaScript, you describe what you want and the agent makes it happen using specialized tools.

**Key Features:**
- 🎨 Build UIs by describing them in plain English
- 🔧 Agent has 9 specialized tools for DOM/CSS/JS manipulation
- 👁️ Live preview updates as changes are made
- 💾 Export finished wireframes as standalone HTML files
- 🔄 Iterative refinement through conversation

---

## Getting Started

### Prerequisites

1. **Koalemos Running:**
   ```bash
   mix phx.server
   ```
   Open http://localhost:4000

2. **Credentials Configured:**
   - See [`CREDENTIALS_SETUP.md`](./CREDENTIALS_SETUP.md) if not set up yet
   - You should see "koalemos is running" on the landing page

### Your First Wireframe

#### Option 1: Follow the Tutorial (Recommended for Beginners)

1. **Open the Tutorial:**
   - Go to http://localhost:4000
   - Click "start with a tutorial" card
   - Or direct link: http://localhost:4000/example/login-form

2. **Follow the Steps:**
   - The tutorial provides exact messages to copy/paste
   - Shows you what to expect at each step
   - Builds a complete login form step-by-step

3. **Learn by Doing:**
   - See how the agent uses tools
   - Understand the conversation pattern
   - Get comfortable with the workflow

**Time Required:** ~5-10 minutes

---

#### Option 2: Free Play (Jump Right In)

1. **Start a Chat:**
   - Go to http://localhost:4000
   - Click "try the demo" (recommended) card
   - Or direct link: http://localhost:4000/test/wireframe

2. **Describe What You Want:**
   ```
   Build a landing page for a coffee shop with:
   - Large hero section with background image
   - Three feature cards (Coffee, Pastries, Atmosphere)
   - Contact form at the bottom
   - Warm, inviting color scheme
   ```

3. **Watch It Build:**
   - Agent will create the initial structure
   - Preview updates in real-time on the right
   - Agent explains what it's doing

4. **Refine Iteratively:**
   ```
   Make the hero section taller and add a call-to-action button
   ```

   ```
   Change the color scheme to use earth tones
   ```

   ```
   Add hover effects to the feature cards
   ```

**Time Required:** ~2-5 minutes per wireframe

---

## Understanding the Interface

### Layout

```
┌────────────────────────────────────────────────────────┐
│  Header: Model info, status, routine ID               │
├──────────────────────┬─────────────────────────────────┤
│                      │                                 │
│   Conversation       │      Live Preview               │
│   (left panel)       │      (right panel)              │
│                      │                                 │
│   - Chat history     │   - Your wireframe renders here │
│   - Tool executions  │   - Updates in real-time        │
│   - Agent thinking   │   - Fully interactive           │
│                      │                                 │
├──────────────────────┴─────────────────────────────────┤
│  Input: Type your message, attach images, send        │
└────────────────────────────────────────────────────────┘
```

### Conversation Panel (Left)

**Message Types:**

1. **Your Messages** (blue, right-aligned)
   - Your requests and feedback

2. **Agent Messages** (gray, left-aligned)
   - Agent's responses and explanations

3. **Tool Executions** (purple cards)
   - Shows which tool was used
   - Displays tool parameters
   - Shows execution results

4. **Thinking Cards** (yellow/amber cards, collapsed by default)
   - Agent's step-by-step reasoning
   - Click to expand and see thought process

### Preview Panel (Right)

- **Live rendering** of your wireframe
- **Fully interactive** - click buttons, fill forms, etc.
- **Updates automatically** when agent makes changes
- **Save button** (top-right) to download HTML file

### Status Indicators

- **Running** (blue, pulsing): Agent is working
- **Completed** (gray): Session finished
- **Error** (red, pulsing): Something went wrong

---

## How to Use the Wireframe Editor

### Basic Workflow

```
1. Describe what you want
   ↓
2. Agent builds initial version
   ↓
3. Review the preview
   ↓
4. Request changes/refinements
   ↓
5. Repeat 3-4 until satisfied
   ↓
6. Save/export the final wireframe
```

### Best Practices for Prompts

#### ✅ Good Prompts (Clear, Specific)

**Initial Build:**
```
Build a product card with:
- Product image at the top (placeholder)
- Product name as h2
- Price in large text
- "Add to Cart" button in blue
- Centered layout, max width 300px
```

**Refinements:**
```
Make the button green and add a hover effect
```

```
Add a 5-star rating display below the price
```

**Styling:**
```
Use a modern, minimalist design with lots of white space
```

```
Add subtle shadows to make it pop
```

#### ❌ Avoid Vague Prompts

**Too Vague:**
```
Make it look nice
```
Better: Specify WHAT you want (colors, spacing, effects)

**Too Complex:**
```
Build a complete e-commerce site with product catalog, shopping cart, checkout flow, user authentication, admin panel, and payment processing
```
Better: Start with ONE component, build up iteratively

**No Context:**
```
Change the blue one
```
Better: Specify WHAT to change ("Change the button color to green")

### Example Sessions

#### Example 1: Contact Form

**Step 1 - Initial Request:**
```
Build a contact form with:
- Name and Email fields
- Message textarea
- Submit button
- Clean, professional styling
```

**Step 2 - Refinement:**
```
Add field labels and make required fields show an asterisk
```

**Step 3 - Polish:**
```
Add validation styling - green border for valid, red for invalid
```

**Step 4 - Interactive:**
```
Make the submit button show "Sending..." when clicked
```

---

#### Example 2: Pricing Table

**Step 1 - Structure:**
```
Build a pricing table with 3 tiers:
- Basic: $9/month
- Pro: $29/month (highlight this one)
- Enterprise: $99/month

Each tier should list 3-4 features
```

**Step 2 - Styling:**
```
Use a gradient background and make the Pro tier stand out with a larger size and border
```

**Step 3 - Interactivity:**
```
Add hover effects to the cards and make the buttons change color on hover
```

---

#### Example 3: Dashboard Layout

**Step 1 - Layout:**
```
Create a dashboard layout with:
- Sidebar navigation on the left (20% width)
- Main content area (80% width)
- 4 stat cards in a grid at the top
- Table of recent activity below
```

**Step 2 - Refinement:**
```
Add icons to the stat cards and make them colorful
```

**Step 3 - Data:**
```
Fill the table with sample data (5 rows)
```

---

## Agent Capabilities (Tools)

The agent has 9 specialized tools for wireframe manipulation:

### 1. **init_wireframe**
- Creates initial HTML structure
- Sets up basic layout and styles
- First tool used in any session

### 2. **modify_element**
- Changes existing elements (text, attributes, content)
- Most frequently used tool for edits

### 3. **add_child_element**
- Adds new elements inside existing ones
- Builds up component hierarchy

### 4. **remove_element**
- Deletes elements from DOM
- Cleans up unwanted parts

### 5. **rearrange_children**
- Changes order of sibling elements
- Reorganizes layouts

### 6. **modify_styles**
- Updates CSS styles for elements
- Controls appearance

### 7. **add_event_handler**
- Adds JavaScript interactivity
- Handles clicks, hovers, form submissions

### 8. **update_variable**
- Changes JavaScript variables
- Updates dynamic content

### 9. **get_current_state**
- Retrieves current HTML/CSS/JS
- Used by agent to understand current state

**You don't need to know these tools!** Just describe what you want, and the agent chooses the right tools automatically.

---

## Advanced Features

### Screenshot Feedback

The agent can "see" your wireframe:

```
Does this layout look balanced?
```

The agent will capture a screenshot and analyze it visually.

**Use cases:**
- Layout review
- Color harmony check
- Visual debugging

### Image Upload

You can upload reference images:

1. Click the image icon in the input area
2. Select an image (design mockup, screenshot, etc.)
3. Agent can reference it while building

**Example:**
```
[Upload image of a card design]

Build a card component that looks like this image
```

### Console Output

If JavaScript code logs to console, the agent sees it and can debug issues.

### Saving Wireframes

**To save your wireframe:**

1. **Click "Save Page" button** (top-right of preview)
2. **Browser downloads:** `wireframe-[timestamp].html`
3. **Open the file:** Works as standalone HTML (no dependencies)

**What's included:**
- All HTML structure
- All CSS styles (inline)
- All JavaScript code
- Fully self-contained and portable

**Sharing:**
- Email the HTML file
- Upload to web host
- Open directly in browser

---

## Troubleshooting

### Agent Isn't Responding

**Symptoms:**
- Message sent, but no response
- Status stuck on "Running"

**Solutions:**
- Check credentials are valid (see CREDENTIALS_SETUP.md)
- Check browser console for errors (F12 → Console tab)
- Refresh the page and try again
- Verify LLM provider is accessible (API not down)

### Preview Not Updating

**Symptoms:**
- Agent makes changes, but preview stays the same
- Preview shows old version

**Solutions:**
- Refresh the preview panel (reload page)
- Check browser console for JavaScript errors
- Clear browser cache

### Agent Makes Wrong Changes

**Symptoms:**
- Agent modifies the wrong element
- Changes don't match your request

**Solutions:**
- **Be more specific:**
  - "Change the blue button" → "Change the blue 'Submit' button in the contact form"
- **Use element descriptions:**
  - "the heading" → "the h2 heading that says 'Welcome'"
- **Request corrections:**
  - "That's not right, I meant the other button"

### Styling Issues

**Symptoms:**
- Colors look off
- Layout is broken
- Elements overlap

**Solutions:**
- **Describe the problem:**
  ```
  The text is overlapping the image. Can you fix the layout?
  ```

- **Request specific fixes:**
  ```
  Add more padding between the elements
  ```

- **Start over if needed:**
  ```
  Let's start fresh. Build a simple card with just an image and title.
  ```

### JavaScript Not Working

**Symptoms:**
- Buttons don't respond to clicks
- Interactive features broken

**Solutions:**
- **Check console:**
  - F12 → Console tab
  - Look for JavaScript errors
  - Share errors with agent:
    ```
    The console shows: "Uncaught TypeError: ..."
    Can you fix this error?
    ```

- **Request debugging:**
  ```
  The button click isn't working. Can you check the event handler?
  ```

### Agent Doesn't Understand Request

**Symptoms:**
- Agent asks clarifying questions
- Agent makes incorrect assumptions

**Solutions:**
- **Provide more context:**
  - "Add a button" → "Add a blue button labeled 'Subscribe' below the email input"

- **Break into steps:**
  - Instead of complex request, do it in 2-3 smaller steps

- **Use examples:**
  - "Make it look like a typical blog post card"

---

## Tips & Tricks

### Iterative Refinement

**Start simple, build up:**
```
1. "Build a basic card with image and title"
2. "Add a description below the title"
3. "Add a button at the bottom"
4. "Style it with a modern look"
5. "Add hover effects"
```

This is better than one complex request with all requirements.

### Use Domain Language

The agent understands web design terminology:

- "Hero section" → Large top section with background
- "Card layout" → Contained component with border/shadow
- "CTA button" → Call-to-action button (prominent)
- "Navbar" → Navigation bar
- "Footer" → Bottom section with links/info

### Request Specific Styles

Instead of "make it pretty":
- "Use a blue gradient background"
- "Add subtle drop shadows"
- "Use the Inter font family"
- "Make it mobile-responsive"

### Build Components, Then Combine

**Better workflow:**
```
1. Build navbar component
2. Build hero section
3. Build features section
4. "Combine all three into a landing page"
```

vs. trying to build everything at once.

### Save Checkpoints

When you reach a good state:
```
This looks great! Can you show me the current HTML?
```

Copy/save the code, then continue iterating. If something breaks, you can restore.

---

## Example Workflows

### Workflow 1: Portfolio Page

```
Session 1: Build header with name and navigation
Session 2: Add a projects grid (3 columns)
Session 3: Add project cards with image, title, description
Session 4: Add contact section at bottom
Session 5: Polish with animations and hover effects
```

### Workflow 2: Landing Page

```
Session 1: Build hero section with headline and CTA
Session 2: Add 3 feature cards below hero
Session 3: Add testimonials section
Session 4: Add pricing table
Session 5: Add footer with links
Session 6: Refine colors and spacing
```

### Workflow 3: Form Component

```
Session 1: Build basic form structure (inputs + button)
Session 2: Add labels and placeholders
Session 3: Add validation styling
Session 4: Add client-side validation logic
Session 5: Style submit button and add loading state
```

---

## FAQ

**Q: Can I upload my own images?**
A: The wireframe editor uses placeholders (placeholder.com, picsum.photos). To use custom images, save the HTML and edit the `src` attributes locally.

**Q: Can I use this for production websites?**
A: The wireframes are prototypes, not production-ready code. Use them as starting points, then refactor and optimize for production.

**Q: Can the agent build complex multi-page apps?**
A: The editor is designed for single-page wireframes. For multi-page, build each page separately and combine manually.

**Q: What's the difference between this and Copilot/ChatGPT?**
A: Koalemos is a specialized agent with **tool use** - it doesn't just generate code, it *executes changes* using structured tools and shows you live previews.

**Q: Can I customize the agent's behavior?**
A: Yes! Koalemos is a framework. You can modify routines, add lenses, and create custom workflows. See [`LENS_DEVELOPMENT.md`](./LENS_DEVELOPMENT.md) and [`ROUTINE_DEVELOPMENT.md`](./ROUTINE_DEVELOPMENT.md).

**Q: Can I contribute new features?**
A: Absolutely! See [`CONTRIBUTING.md`](../CONTRIBUTING.md) for guidelines.

---

## Next Steps

### Learn More

- **Architecture:** [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) - How Koalemos works
- **Build Lenses:** [`docs/guides/LENS_DEVELOPMENT.md`](./LENS_DEVELOPMENT.md) - Add new capabilities
- **Build Routines:** [`docs/guides/ROUTINE_DEVELOPMENT.md`](./ROUTINE_DEVELOPMENT.md) - Create workflows

### Get Creative

- Build a portfolio page
- Create a landing page for a product
- Design a dashboard UI
- Prototype a mobile app interface
- Experiment with different design styles

### Share Your Work

- Export your wireframes
- Share screenshots
- Post examples and get feedback
- Contribute example wireframes to the project

---

**Happy wireframing! 🎨**
