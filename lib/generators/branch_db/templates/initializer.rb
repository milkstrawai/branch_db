return unless defined?(BranchDb)

BranchDb.configure do |config|
  # The name of your main/stable branch (default: 'main')
  # config.main_branch = 'main'

  # Maximum length for branch name suffix in database names (default: 33)
  # PostgreSQL has a 63 character limit for database names
  # Ensure: base_name_length + 1 + max_branch_length <= 63
  # config.max_branch_length = 33

  # Database name suffixes for dev/test environment matching (default: '_development', '_test')
  # Used by cleanup to find corresponding test databases for each dev database
  # Customize if your database names use different suffixes (e.g., '_dev', '_test')
  # config.development_suffix = '_development'
  # config.test_suffix = '_test'
end
