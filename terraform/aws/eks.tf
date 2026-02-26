# AWS EKS Configuration
# REFACTORED: EKS resources are now organized in modules
# See: main.tf for module usage
# 
# Module Structure:
# ├── modules/
# │   ├── cluster/         - EKS cluster + IAM role
# │   ├── node_group/      - Node group + node IAM roles
# │   └── security_group/  - Security groups for cluster and nodes
#
# These modules are imported and combined in main.tf
# This modular approach provides:
# - Better code organization
# - Reusability across projects
# - Easier maintenance and updates
# - Clear separation of concerns

