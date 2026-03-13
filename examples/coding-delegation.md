# Coding Delegation Example

Real-world example: delegating a coding task to qwen3-coder.

## Scenario

You need to implement a new feature: a REST API endpoint for user registration.

## Step 1: Prepare the Task

Before spawning, ensure:
- Task is atomic (one endpoint, self-contained)
- Context is clear (what already exists, constraints)
- Output path specified

## Step 2: Spawn the Subagent

Using the orchestrator-led pattern:

```markdown
## Task: Implement user registration endpoint

## Context
We are building a REST API. Need a POST /register endpoint that:
- Accepts email and password
- Validates email format
- Hashes password with bcrypt
- Returns user ID on success

Existing: app.py has Flask setup, database connection ready.

## Your Role
You are a coding specialist (qwen3-coder).

## What To Do
1. Write the registration endpoint code
2. Include input validation
3. Include password hashing
4. Include error handling

## What NOT To Do
- Do NOT create files directly - provide code in your report
- Do NOT update any project files

## Expected Output
Python code for the endpoint that I will add to app.py

## Report Format
```markdown
## Task Complete

**Work Done:** [Brief description]

**Code:** [The Python code]

**Integration Notes:** [Any notes on how to integrate]
```
```

## Step 3: Wait for Results

Do NOT poll. Wait for completion event.

## Step 4: Verify and Integrate

When subagent reports back:

1. **Verify code exists** - Check the reported code
2. **Test locally** - If possible, run a quick syntax check
3. **Integrate** - Add code to app.py yourself
4. **Report** - Summarize to user

```python
# Example: What you add to app.py
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    # Validate email
    if not email or '@' not in email:
        return jsonify({'error': 'Invalid email'}), 400
    
    # Hash password
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
    
    # Save to database (pseudo-code)
    user_id = db.users.insert({'email': email, 'password': hashed})
    
    return jsonify({'user_id': user_id}), 201
```

## Step 5: Summary to User

```markdown
✅ **User Registration Endpoint** - Implemented

- Created POST /register endpoint
- Email validation + bcrypt password hashing
- Code added to app.py
- Ready for testing
```

---

## Key Takeaways

1. **Clear requirements** - Specify what the endpoint should do
2. **Existing context** - Mention what's already in place
3. **No tool syntax** - Don't mention `write` tool
4. **Orchestrator integrates** - Subagent provides code, you add it
5. **Verify first** - Check syntax before claiming complete

---

## Related Documents

- [templates/delegation-prompt.md](../templates/delegation-prompt.md) - Spawn template
- [docs/orchestrator-pattern.md](../docs/orchestrator-pattern.md) - Core pattern
- [examples/research-delegation.md](research-delegation.md) - Research example
