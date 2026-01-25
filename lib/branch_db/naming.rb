module BranchDb
  module Naming
    extend GitUtils

    class << self
      def main_database_name(base_name) = "#{base_name}#{BranchDb.configuration.main_branch}"

      def database_name(base_name) = "#{base_name}#{branch_suffix}"

      def branch_suffix = suffix_for(current_branch)

      def suffix_for(branch)
        branch = sanitize_branch(branch)
        max_length = BranchDb.configuration.max_branch_length
        truncated = branch[0, max_length]
        truncated.empty? ? "" : "_#{truncated}"
      end

      def parent_database_name(base_name) = "#{base_name}_#{sanitize_branch(parent_branch)}"

      def sanitize_branch(branch) = branch.gsub(/[^a-zA-Z0-9_]/, "_")
    end
  end
end
