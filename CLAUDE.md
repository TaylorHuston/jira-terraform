# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform project for managing JIRA infrastructure. The project uses Infrastructure as Code (IaC) principles to provision and manage JIRA-related resources.

## Commands

### Terraform Operations
- **Format code**: `terraform fmt` - Auto-formats all Terraform files to canonical format
- **Validate configuration**: `terraform validate` - Validates the Terraform configuration syntax
- **Plan changes**: `terraform plan` - Shows what changes will be made without applying them
- **Apply changes**: `terraform apply` - Applies the Terraform configuration to create/update infrastructure
- **Initialize**: `terraform init` - Initializes the Terraform working directory (required before other commands)

### Development Workflow
1. Always run `terraform fmt` before committing changes
2. Run `terraform validate` to check configuration validity
3. Use `terraform plan` to review changes before applying
4. Apply changes with `terraform apply` only after reviewing the plan

## Terraform Best Practices for this Project

When working with Terraform files in this repository:
- Follow HCL (HashiCorp Configuration Language) best practices
- Use consistent formatting with `terraform fmt`
- Always validate changes with `terraform validate` before planning
- Review terraform plan output carefully before applying changes
- Use meaningful resource names and descriptions
- Group related resources in appropriate .tf files
- Keep sensitive values in .tfvars files (never commit these)
- Use variables for values that change between environments

## Project Structure

- Terraform configuration files (.tf) should be organized by resource type or logical grouping
- Variable definitions should be in variables.tf
- Outputs should be defined in outputs.tf
- Provider configuration should be in providers.tf or main.tf
- Environment-specific values should use .tfvars files