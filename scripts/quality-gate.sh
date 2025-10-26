#!/bin/bash
# Quality Gate Script for Docker Travian
# Enforces enterprise-grade code quality standards

set -e

echo "=================================="
echo "Docker Travian - Quality Gate"
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILED=0

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# PHP Quality Checks
echo -e "\n${YELLOW}Running PHP Quality Checks...${NC}"
if command_exists php; then
    # PHP Syntax Check
    echo "Checking PHP syntax..."
    find src/php -name "*.php" -exec php -l {} \; || FAILED=1
    
    # PHPStan Analysis
    if [ -f vendor/bin/phpstan ]; then
        echo "Running PHPStan analysis..."
        vendor/bin/phpstan analyse src/php --level=9 || FAILED=1
    fi
    
    # PHP CodeSniffer
    if [ -f vendor/bin/phpcs ]; then
        echo "Running PHP CodeSniffer..."
        vendor/bin/phpcs --standard=PSR12 src/php || FAILED=1
    fi
else
    echo -e "${YELLOW}PHP not found, skipping PHP checks${NC}"
fi

# JavaScript/TypeScript Quality Checks
echo -e "\n${YELLOW}Running JavaScript Quality Checks...${NC}"
if command_exists npm; then
    # ESLint
    if [ -f node_modules/.bin/eslint ]; then
        echo "Running ESLint..."
        npx eslint src/js --ext .js,.ts || FAILED=1
    fi
    
    # Check for console.log statements
    echo "Checking for console.log statements..."
    if grep -r "console.log" src/js --include="*.js" --include="*.ts"; then
        echo -e "${RED}Found console.log statements in production code!${NC}"
        FAILED=1
    fi
else
    echo -e "${YELLOW}NPM not found, skipping JavaScript checks${NC}"
fi

# Security Checks
echo -e "\n${YELLOW}Running Security Checks...${NC}"

# Check for hardcoded passwords
echo "Checking for hardcoded passwords..."
if grep -r "password\s*=\s*[\"'][^\"']*[\"']" src/ --include="*.php" --include="*.js"; then
    echo -e "${RED}Found hardcoded passwords!${NC}"
    FAILED=1
fi

# Check for SQL injection vulnerabilities
echo "Checking for potential SQL injection..."
if grep -r "mysql_query\|mysqli_query" src/php --include="*.php"; then
    echo -e "${RED}Found direct SQL queries! Use prepared statements!${NC}"
    FAILED=1
fi

# Code Duplication Check
echo -e "\n${YELLOW}Checking for Code Duplication...${NC}"
if command_exists jscpd; then
    jscpd src --threshold 2 --reporters console || FAILED=1
else
    echo -e "${YELLOW}JSCPD not found, skipping duplication check${NC}"
fi

# Complexity Check
echo -e "\n${YELLOW}Checking Code Complexity...${NC}"
if [ -f scripts/complexity-check.py ]; then
    python3 scripts/complexity-check.py || FAILED=1
else
    echo -e "${YELLOW}Complexity checker not found${NC}"
fi

# Docker Security Scan
echo -e "\n${YELLOW}Scanning Docker Images...${NC}"
if command_exists docker; then
    # Check if Trivy is available
    if command_exists trivy; then
        echo "Running Trivy security scan..."
        trivy fs . --severity HIGH,CRITICAL --exit-code 1 || FAILED=1
    else
        echo -e "${YELLOW}Trivy not found, skipping container scan${NC}"
    fi
fi

# Test Coverage Check
echo -e "\n${YELLOW}Checking Test Coverage...${NC}"
if [ -f vendor/bin/phpunit ]; then
    echo "Running PHPUnit tests..."
    vendor/bin/phpunit --coverage-text --coverage-html=coverage || FAILED=1
    
    # Check coverage threshold (85%)
    COVERAGE=$(vendor/bin/phpunit --coverage-text | grep "Lines:" | awk '{print $2}' | sed 's/%//')
    if [ "$COVERAGE" -lt "85" ]; then
        echo -e "${RED}Test coverage ($COVERAGE%) is below threshold (85%)${NC}"
        FAILED=1
    fi
fi

# Final Report
echo -e "\n=================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All quality gates passed!${NC}"
    echo "=================================="
    exit 0
else
    echo -e "${RED}✗ Quality gates failed!${NC}"
    echo "=================================="
    echo "Please fix the issues above before committing."
    exit 1
fi
