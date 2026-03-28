# ORCHESTRATOR_VERIFY — Post-Subagent Verification Protocol

## When
After any subagent reports completion. BEFORE orchestrator writes any file.

## Steps

1. **Check results/ directory**
   Look for: ~/.openclaw/workspace/results/<project>/
   If files exist → they are the authoritative output
   If files missing → orchestrator must do the work directly (not re-delegate)

2. **Never assume subagent failed without checking**
   Compaction can kill delivery. Subagent may have completed and written to results/.
   Check results/ FIRST. Always.

3. **Copy results to workspace**
   After verifying results/ has output:
   - Read output from results/<project>/*.json
   - Copy content to the actual destination files
   - Verify copy succeeded (read back)

4. **If results/ is empty**
   - Do NOT re-delegate the same task
   - Orchestrator completes the work directly
   - This prevents infinite retry loops

## Anti-pattern (never do)
"Subagent didn't deliver → I should redo the work"
RIGHT: "Subagent didn't deliver → let me check results/ first"
