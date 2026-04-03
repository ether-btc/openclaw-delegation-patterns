#!/bin/bash
# scripts/elegance-check.sh
# Checks code for elegance criteria
# Usage: elegance-check.sh --files "path/to/files" [--min-score 70] [--bypass-elegance]

set -euo pipefail

# Default settings
MIN_SCORE=70
BYPASS=false
VERBOSE=false

# Parse arguments
FILES=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --files)
            FILES="$2"
            shift 2
            ;;
        --file)
            FILES="$2"
            shift 2
            ;;
        --min-score)
            MIN_SCORE="$2"
            shift 2
            ;;
        --bypass-elegance)
            BYPASS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check bypass
if [ "$BYPASS" = true ]; then
    echo "🟢 Elegance check bypassed"
    exit 0
fi

# Validate required arguments
if [ -z "$FILES" ]; then
    echo "Error: --files is required"
    exit 1
fi

# Check if files exist
if [ ! -e "$FILES" ]; then
    echo "Error: Files not found: $FILES"
    exit 1
fi

# Score tracking
TOTAL_SCORE=0
MAX_SCORE=0
VIOLATIONS=()

# Elegance check functions
check_file() {
    local file="$1"
    local file_score=0
    local file_max=0
    
    echo "Checking: $file"
    
    # Get file extension
    local ext="${file##*.}"
    local line_count
    line_count=$(wc -l < "$file")
    
    # Check 1: Simplicity (weight: 3, max: 15)
    file_max=$((file_max + 15))
    local simplicity_score=15
    
    # Check line count
    if [ "$line_count" -gt 300 ]; then
        VIOLATIONS+=("$file: File too long ($line_count > 300 lines)")
        simplicity_score=$((simplicity_score - 5))
    fi
    
    # Check nesting depth (rough check)
    local max_nesting
    max_nesting=$(grep -co 'if\|for\|while\|switch\|catch' "$file" 2>/dev/null) || true
    if [ "$max_nesting" -gt 10 ]; then
        VIOLATIONS+=("$file: High nesting complexity")
        simplicity_score=$((simplicity_score - 3))
    fi
    
    # Check function length (rough check - functions > 50 lines)
    local long_functions
    long_functions=$(awk '/^function|^const.*=.*=>/ { start=NR } NR-start > 50 { print NR ":" $0 }' "$file" | grep -c .) || true
    if [ "$long_functions" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains long functions")
        simplicity_score=$((simplicity_score - 2))
    fi
    
    file_score=$((file_score + simplicity_score))
    [ $VERBOSE = true ] && echo "  Simplicity: $simplicity_score/15"
    
    # Check 2: Naming (weight: 3, max: 15)
    file_max=$((file_max + 15))
    local naming_score=15
    
    # Check for single-letter variables (excluding common ones)
    local single_letter
    single_letter=$(grep -E '\b[a-z]\b' "$file" | grep -vE '\b(i|j|k|x|y|n|m)\b' | grep -cE '\b(let|const|var)\s+[a-z]\b') || true
    if [ "$single_letter" -gt 2 ]; then
        VIOLATIONS+=("$file: Too many single-letter variables")
        naming_score=$((naming_score - 5))
    fi
    
    # Check for magic numbers
    local magic_numbers
    magic_numbers=$(grep -E '\b[0-9]{2,}\b' "$file" | grep -cvE '^\s*//|^\s*#') || true
    if [ "$magic_numbers" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains magic numbers")
        naming_score=$((naming_score - 3))
    fi
    
    # Check for unclear function names
    local unclear_names
    unclear_names=$(grep -cE '^function\s+[a-z]{1,2}\(|^const\s+[a-z]{1,2}\s*=' "$file" 2>/dev/null) || true
    if [ "$unclear_names" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains unclear function/variable names")
        naming_score=$((naming_score - 3))
    fi
    
    file_score=$((file_score + naming_score))
    [ $VERBOSE = true ] && echo "  Naming: $naming_score/15"
    
    # Check 3: Single Responsibility (weight: 2, max: 10)
    file_max=$((file_max + 10))
    local sr_score=10
    
    # Check for god functions (long parameter lists)
    local god_functions
    god_functions=$(grep -cE 'function\s+\w+\([^)]*,[^)]*,[^)]*,[^)]*' "$file" 2>/dev/null) || true
    if [ "$god_functions" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains functions with many parameters")
        sr_score=$((sr_score - 5))
    fi
    
    file_score=$((file_score + sr_score))
    [ $VERBOSE = true ] && echo "  Single Responsibility: $sr_score/10"
    
    # Check 4: Error Handling (weight: 2, max: 10)
    file_max=$((file_max + 10))
    local eh_score=10
    
    # Check for empty catch blocks
    local empty_catches
    empty_catches=$(grep -A1 'catch' "$file" | grep -cE '^\s*\}\s*$') || true
    if [ "$empty_catches" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains empty catch blocks")
        eh_score=$((eh_score - 8))
    fi
    
    # Check for console.log in production (warning only)
    local console_logs
    console_logs=$(grep -cE 'console\.(log|debug|info)' "$file" 2>/dev/null) || true
    if [ "$console_logs" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains console.log statements")
        eh_score=$((eh_score - 2))
    fi
    
    file_score=$((file_score + eh_score))
    [ $VERBOSE = true ] && echo "  Error Handling: $eh_score/10"
    
    # Check 5: Duplication (weight: 2, max: 10)
    file_max=$((file_max + 10))
    local dup_score=10
    
    # Check for repeated strings (simple heuristic)
    local repeated
    repeated=$(grep -cE '".*".*".*"' "$file" 2>/dev/null) || true
    if [ "$repeated" -gt 3 ]; then
        VIOLATIONS+=("$file: May contain repeated strings")
        dup_score=$((dup_score - 3))
    fi
    
    file_score=$((file_score + dup_score))
    [ $VERBOSE = true ] && echo "  Duplication: $dup_score/10"
    
    # Check 6: Dependencies (weight: 1, max: 5)
    file_max=$((file_max + 5))
    local dep_score=5
    
    # Check for unnecessary imports
    local import_count
    import_count=$(grep -cE '^import|^require' "$file" 2>/dev/null) || true
    if [ "$import_count" -gt 10 ]; then
        VIOLATIONS+=("$file: Many imports - consider reducing")
        dep_score=$((dep_score - 2))
    fi
    
    file_score=$((file_score + dep_score))
    [ $VERBOSE = true ] && echo "  Dependencies: $dep_score/5"
    
    # Check 7: Comments (weight: 1, max: 5)
    file_max=$((file_max + 5))
    local comment_score=5
    
    # Check for commented-out code
    local commented_out
    commented_out=$(grep -cE '^\s*//\s*(function|const|let|var|if|for|while)' "$file" 2>/dev/null) || true
    if [ "$commented_out" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains commented-out code")
        comment_score=$((comment_score - 3))
    fi
    
    # Check for useless comments
    local useless_comments
    useless_comments=$(grep -cE '^\s*//\s*(add|sub|mul|div|increment|decrement|get|set)\s' "$file" 2>/dev/null) || true
    if [ "$useless_comments" -gt 0 ]; then
        VIOLATIONS+=("$file: Contains useless comments")
        comment_score=$((comment_score - 1))
    fi
    
    file_score=$((file_score + comment_score))
    [ $VERBOSE = true ] && echo "  Comments: $comment_score/5"
    
    # Check 8: Shell Security — Path Injection & Credential Leaks (weight: 3, max: 15)
    # Patterns from script-hygiene audit (2026-04-02)
    file_max=$((file_max + 15))
    local sec_score=15

    # P1: while-read without IFS= (filename splitting on spaces/special chars)
    local unquoted_while_read=0
    unquoted_while_read=$(grep -cE 'while read\s+[a-zA-Z_][a-zA-Z0-9_]*\$' "$file" 2>/dev/null) || true
    if [ "$unquoted_while_read" -gt 0 ]; then
        VIOLATIONS+=("$file: while-read without IFS= (path injection risk: $unquoted_while_read)")
        sec_score=$((sec_score - 5))
    fi

    # P2: jq without -- before input file (path injection via --庭 chars in filenames)
    local unquoted_jq=0
    local jq_lines
    jq_lines=$(grep -nE 'jq\s' "$file" 2>/dev/null) || true
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "$line" | grep -qE "jq\\s+[^']*\\s+--\\s+" && continue
        local jq_pattern
        jq_pattern="jq\\s+[^']*\\s+\\\$\\{?[a-zA-Z_][a-zA-Z0-9_]*[/[_](FILE|PATH|DIR|CONFIG|SINK|CHECKPOINT|VAULT|METRIC|SESSION)[_]?]"
        echo "$line" | grep -qE "$jq_pattern" || continue
        unquoted_jq=$((unquoted_jq + 1))
    done <<< "$jq_lines"
    if [ "$unquoted_jq" -gt 0 ]; then
        VIOLATIONS+=("$file: jq without -- before input file (path injection risk: $unquoted_jq)")
        sec_score=$((sec_score - 5))
    fi

    # P3: eval on command output (RCE risk if output is externally controlled)
    local eval_count=0
    eval_count=$(grep -cE 'eval\s+\$\(' "$file" 2>/dev/null) || true
    if [ "$eval_count" -gt 0 ]; then
        VIOLATIONS+=("$file: eval on command output (RCE risk: $eval_count)")
        sec_score=$((sec_score - 8))
    fi

    # P4: Credential/env-var printed in output
    local cred_leak=0
    cred_leak=$(grep -cE 'echo\s+.*\$\{?(BRAVE|FIRECRAWL|API|TOKEN|SECRET|PASSWORD|KEY)[A-Z_]*' "$file" 2>/dev/null) || true
    if [ "$cred_leak" -gt 0 ]; then
        VIOLATIONS+=("$file: Credential/env-var in echo output ($cred_leak)")
        sec_score=$((sec_score - 3))
    fi

    file_score=$((file_score + sec_score))
    [ "$VERBOSE" = true ] && echo "  Shell Security: $sec_score/15"

    # Check 9: Testing (weight: 1, max: 5) - skipped for non-test files
    file_max=$((file_max + 5))
    local test_score=5

    if [[ "$file" == *".test."* || "$file" == *".spec."* ]]; then
        # Test files get full score
        test_score=5
    else
        # Non-test files: check for corresponding test
        local base_name="${file%.*}"
        local test_file="${base_name}.test.${ext}"
        if [ ! -f "$test_file" ]; then
            test_score=3  # No test found, partial score
        fi
    fi
    
    file_score=$((file_score + test_score))
    [ $VERBOSE = true ] && echo "  Testing: $test_score/5"
    
    # Calculate percentage
    if [ "$file_max" -gt 0 ]; then
        local file_percent=$((file_score * 100 / file_max))
        echo "  Score: $file_percent/100 ($file_score/$file_max)"
        
        # Rating
        if [ "$file_percent" -ge 85 ]; then
            echo "  Rating: 🟢 EXCELLENT"
        elif [ "$file_percent" -ge 70 ]; then
            echo "  Rating: 🟡 GOOD"
        elif [ "$file_percent" -ge 50 ]; then
            echo "  Rating: 🟠 NEEDS WORK"
        else
            echo "  Rating: 🔴 NOT ELEGANT"
        fi
    fi
    
    TOTAL_SCORE=$((TOTAL_SCORE + file_score))
    MAX_SCORE=$((MAX_SCORE + file_max))
}

# Process files
echo "=== Elegance Check ==="
echo "Files: $FILES"
echo "Minimum Score: $MIN_SCORE"
echo ""

# Expand glob if needed
if [[ "$FILES" == *"*"?* ]]; then
    for file in $FILES; do
        if [ -f "$file" ]; then
            check_file "$file"
        fi
    done
else
    check_file "$FILES"
fi

# Calculate overall score
if [ "$MAX_SCORE" -gt 0 ]; then
    OVERALL_SCORE=$((TOTAL_SCORE * 100 / MAX_SCORE))
    
    echo ""
    echo "=== Overall Score: $OVERALL_SCORE/100 ==="
    
    # Rating
    if [ "$OVERALL_SCORE" -ge 85 ]; then
        OVERALL_RATING="🟢 EXCELLENT"
    elif [ "$OVERALL_SCORE" -ge 70 ]; then
        OVERALL_RATING="🟡 GOOD"
    elif [ "$OVERALL_SCORE" -ge 50 ]; then
        OVERALL_RATING="🟠 NEEDS WORK"
    else
        OVERALL_RATING="🔴 NOT ELEGANT"
    fi
    
    echo "Rating: $OVERALL_RATING"
fi

# Show violations
if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    echo ""
    echo "=== Violations (${#VIOLATIONS[@]}) ==="
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v"
    done
fi

# Exit code based on score
if [ "$OVERALL_SCORE" -lt "$MIN_SCORE" ]; then
    echo ""
    echo "❌ FAILED: Score $OVERALL_SCORE < minimum $MIN_SCORE"
    exit 1
else
    echo ""
    echo "✅ PASSED: Score $OVERALL_SCORE >= minimum $MIN_SCORE"
    exit 0
fi