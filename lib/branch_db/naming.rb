module BranchDb
  module Naming
    extend GitUtils

    class << self
      def main_database_name(base_name) = "#{base_name}#{suffix_for(BranchDb.configuration.main_branch)}"

      def database_name(base_name)
        override = override_for(base_name)
        return override if override && !override.empty?

        "#{base_name}#{branch_suffix}"
      end

      def branch_suffix = suffix_for(current_branch)

      def suffix_for(branch)
        branch = sanitize_branch(branch)
        max_length = BranchDb.configuration.max_branch_length
        truncated = branch[0, max_length]
        truncated.empty? ? "" : "_#{truncated}"
      end

      def parent_database_name(base_name) = "#{base_name}_#{sanitize_branch(parent_branch)}"

      def sanitize_branch(branch) = branch.gsub(/[^a-zA-Z0-9_]/, "_")

      private

      def override_for(base_name)
        config = BranchDb.configuration

        if base_name.end_with?(config.development_suffix)
          ENV.fetch("BRANCH_DB_DATABASE_DEVELOPMENT", nil)
        elsif base_name.end_with?(config.test_suffix)
          ENV.fetch("BRANCH_DB_DATABASE_TEST", nil)
        end
      end
    end
  end
end
