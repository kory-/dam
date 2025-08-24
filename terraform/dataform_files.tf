# Note: Direct file management in Dataform repositories via Terraform is limited.
# Files need to be managed through Git integration or the Dataform UI.
# 
# For production use, consider:
# 1. Using Git integration with google_dataform_repository.git_remote_settings
# 2. Using the Dataform CLI to push files
# 3. Using the Dataform API directly via null_resource with local-exec

# Dataform execution is handled by Google Workflows (dam-daily-pipeline)
# No automatic scheduling is configured here