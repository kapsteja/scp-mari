terraform {
 cloud {
   organization = "marriott"
   workspaces {
     name = "cf-aws-org-scp-v2"
   }
 }
}
