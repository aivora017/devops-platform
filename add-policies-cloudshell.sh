#!/bin/bash
# CloudShell Script: Add IAM Policies to terraform-user
# Usage: Paste this entire script into AWS CloudShell and run it

set -e

echo "==========================================="
echo "Adding IAM Policies to terraform-user"
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if user exists
echo -e "${BLUE}Checking if terraform-user exists...${NC}"
if aws iam get-user --user-name terraform-user &>/dev/null; then
    echo -e "${GREEN}✅ terraform-user found${NC}"
else
    echo -e "${YELLOW}❌ terraform-user not found!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Attaching IAM policies...${NC}"
echo ""

# Array of policies to attach
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    "arn:aws:iam::aws:policy/AmazonEKSFullAccess"
    "arn:aws:iam::aws:policy/IAMFullAccess"
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
    "arn:aws:iam::aws:policy/AutoScalingFullAccess"
)

# Attach each policy
for policy in "${POLICIES[@]}"; do
    policy_name=$(echo $policy | rev | cut -d'/' -f1 | rev)
    echo -n "Attaching $policy_name... "
    
    if aws iam attach-user-policy --user-name terraform-user --policy-arn "$policy" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
    else
        # Check if already attached
        if aws iam list-attached-user-policies --user-name terraform-user | grep -q "$policy_name"; then
            echo -e "${YELLOW}⚠️  (already attached)${NC}"
        else
            echo -e "${YELLOW}❌ Failed${NC}"
        fi
    fi
done

echo ""
echo "==========================================="
echo "Verification"
echo "==========================================="
echo ""

echo -e "${BLUE}Attached policies:${NC}"
aws iam list-attached-user-policies --user-name terraform-user --query 'AttachedPolicies[*].[PolicyName]' --output text

echo ""
echo -e "${GREEN}✅ All policies attached successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Close CloudShell"
echo "2. Return to your terminal"
echo "3. Run: cd /home/sourav/devops-platform && bash scripts/deploy-complete.sh"
