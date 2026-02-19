#!/bin/bash

# GreenHive UI Standards Checker
# This script checks for common UI standard violations in the codebase.
# Run this before committing to ensure UI consistency.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"

echo "🎨 Checking GreenHive UI Standards..."
echo ""

# Color for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to count and report violations
check_pattern() {
    local pattern="$1"
    local description="$2"
    local suggestion="$3"
    local is_error="${4:-true}"
    
    # Exclude theme files, test files, and lines with ignore comment
    local count=$(grep -rn "$pattern" "$LIB_DIR" --include="*.dart" 2>/dev/null \
        | grep -v "AppColors\." \
        | grep -v "shared/themes/" \
        | grep -v "test/" \
        | grep -v "// ignore-ui-check" \
        | wc -l | tr -d ' ')
    
    if [ "$count" -gt 0 ]; then
        if [ "$is_error" = "true" ]; then
            echo -e "${RED}❌ Found $count instances of $description${NC}"
            ERRORS=$((ERRORS + count))
        else
            echo -e "${YELLOW}⚠️  Found $count instances of $description${NC}"
            WARNINGS=$((WARNINGS + count))
        fi
        echo "   Suggestion: $suggestion"
        echo ""
    fi
}

# Check for hardcoded colors (excluding transparent and theme files)
echo "Checking for hardcoded colors..."
check_pattern "Colors\.\(white\|black\|grey\|green\|blue\|red\|amber\|orange\|purple\|teal\)" \
    "hardcoded Colors.xxx" \
    "Use AppColors.xxx instead" \
    "true"

# Check for hardcoded hex colors (excluding theme files)
check_pattern "Color(0x" \
    "hardcoded Color(0x...) values" \
    "Add the color to AppColors and use the constant" \
    "true"

# Check for hardcoded font sizes (common patterns)
echo "Checking for hardcoded typography..."
check_pattern "fontSize: [0-9]" \
    "hardcoded fontSize values" \
    "Use AppTypography.xxx instead" \
    "false"

# Check for hardcoded EdgeInsets with numeric values
echo "Checking for hardcoded spacing..."
check_pattern "EdgeInsets\.all([0-9]" \
    "hardcoded EdgeInsets.all() values" \
    "Use EdgeInsets.all(AppSpacing.spacingXX) instead" \
    "false"

check_pattern "EdgeInsets\.symmetric(.*[0-9]" \
    "hardcoded EdgeInsets.symmetric() values" \
    "Use AppSpacing constants instead" \
    "false"

# Check for hardcoded border radius
echo "Checking for hardcoded border radius..."
check_pattern "BorderRadius\.circular([0-9]" \
    "hardcoded BorderRadius.circular() values" \
    "Use BorderRadius.circular(AppBorders.radiusXX) instead" \
    "false"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ UI Standards Check FAILED${NC}"
    echo -e "   ${RED}$ERRORS errors${NC} (must fix)"
    echo -e "   ${YELLOW}$WARNINGS warnings${NC} (should fix)"
    echo ""
    echo "Fix the errors above before committing."
    echo "Add '// ignore-ui-check' comment to suppress false positives."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  UI Standards Check PASSED with warnings${NC}"
    echo -e "   ${YELLOW}$WARNINGS warnings${NC} (consider fixing)"
    echo ""
    echo "Consider fixing warnings to improve UI consistency."
    exit 0
else
    echo -e "${GREEN}✅ UI Standards Check PASSED${NC}"
    echo "   No UI standard violations found!"
    exit 0
fi
