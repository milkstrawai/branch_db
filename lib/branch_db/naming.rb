module BranchDb
  module Naming
    extend GitUtils

    class << self
      def sanitize_branch(branch)
        branch.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      def branch_suffix
        branch = sanitize_branch(current_branch)
        max_length = BranchDb.configuration.max_branch_length
        truncated = branch[0, max_length]
        truncated.empty? ? "" : "_#{truncated}"
      end

      def database_name(base_name) = "#{base_name}#{branch_suffix}"

      def main_database_name(base_name) = "#{base_name}_#{BranchDb.configuration.main_branch}"

      def parent_database_name(base_name) = "#{base_name}_#{sanitize_branch(parent_branch)}"
    end
  end
end
