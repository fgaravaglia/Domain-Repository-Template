# Operation Modes

This document defines the **Operation Modes** of the AI agent.
The Agent has alwayst to follow this path:

- Listen to instructions
- Analyze project context
- Identify the type of task requested

then, it has to apply one of the followinf modes:

- Explanation
- Planning Mode
- Implementation Mode

## Explanation Mode

- Activated with: "Explain...", "Analyze...", "Describe..."
- Provides detailed analysis
- Uses practical examples from codebase
- **Objective**: Provide clear and detailed explanations of code, architecture or problems.
- **Process**:
  1. **Analyze**: Examine files, structure, dependencies
  2. **Contextualize**: Connect to business logic
  3. **Explain**: Use simple language and examples
  4. **Suggest**: Propose improvements if necessary
- **Output Format**:
  - Well-structured sections
  - Code examples when useful
  - Diagrams if necessary (markdown)
  - Links to relevant files

## Planning Mode

- Activated with: "Create a plan...", "How to implement..."
- Generates step-by-step strategies
- Requires approval before proceeding
- **Objective**: Create detailed and approvable plans for implementations.
- **Process**:
  1. **Understand**: Clearly define requirements
  2. **Model**: Always start from domain model
  3. **Architect**: Structure solution from inside out
  4. **Plan**: Concrete and measurable steps
  5. **Evaluate**: Risks, impacts, alternatives
- **Rules**:
  - DO NOT implement until I approve the plan
  - Ask for feedback on uncertain points
  - Propose alternatives when appropriate

### Plan Structure

```markdown
## Plan: [Feature Name]

### Requirements
- [req1]
- [req2]

### Domain Model
- Entities: [list]
- Value Objects: [list]
- Aggregates: [list]
- Services: [list]

### Architecture
- [Layer 1]: [responsibility]
- [Layer 2]: [responsibility]

### Implementation Steps
1. [Step 1] - [estimated time]
2. [Step 2] - [estimated time]

### Risks and Mitigations
- Risk: [description] → Mitigation: [solution]

### Files to Modify/Create
- [file1]: [changes]
- [file2]: [changes]
```

## Implementation Mode

- Activated only after plan approval
- Modifies files and code
- Provides feedback on changes
- **Objective**: Implement the approved plan safely and in a structured way.
- **Process**: 
  1. **Confirm**: Verify that the plan is approved
  2. **Prioritize**: Start from domain model
  3. **Implement**: One file at a time, from core outward
  4. **Test**: Verify each component
  5. **Document**: Update documentation if necessary
- **Implementation Rules**:
  - Follow the approved plan order
  - Write clean and well-commented code
  - Handle errors appropriately
  - Make logical and descriptive commits
  - Test each component before proceeding
- **Feedback during implementation**:
  - Communicate each completed file
  - Report any deviations from the plan
  - Ask for confirmation for significant changes

## Token Optimization

- Efficient Context Management:
  - **Principle**: Use only necessary context for current task
  - **Avoid**: Loading entire codebase when only one module needed
  - **Do**: Request specific files with `/include path/to/file.js`
- Token Reduction Techniques:
  1. **Context Chunking**: Break large tasks into small subtasks
  2. **Selective Loading**: Load only files relevant to problem
  3. **Protocol Switching**: Change modes to reset context
  4. **Summary Mode**: Summarize long conversations before continuing
- Anti-Waste Patterns:
  - **NO**: "Analyze entire project"
  - **YES**: "Analyze User module in domain"
  - **NO**: "Explain this function" (without context)  
  - **YES**: "Explain AuthService.login() in auth.js file"

### Token Control Commands

```bash
# Reset context and reload only essential
/reset
/include core/domain/*.js

# Summary mode for long conversations  
/summarize last 20 messages

# Load specific file instead of entire project
/file src/components/UserService.js
```

### Practical Optimization Example

**Instead of:**

```txt
"Implement complete JWT authentication with signup, login, logout, 
refresh token, password reset, email verification in system"
```

**Use:**

```txt
Step 1: "Design User model in domain" 
Step 2: "Implement AuthService for JWT"
Step 3: "Create AuthController with login/signup"
```
