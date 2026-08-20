/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

# Backend values are intentionally omitted here and supplied at `terraform init`
# time via `-backend-config`, so the same configuration can target different
# state stores per environment (see the deploy-tic30-diagnostics.yml workflow).
terraform {
  backend "azurerm" {}
}
