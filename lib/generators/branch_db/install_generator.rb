require "rails/generators/base"

module BranchDb
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    desc "Creates a BranchDb initializer and shows setup instructions"

    def create_initializer
      template "initializer.rb", "config/initializers/branch_db.rb"
    end

    def show_instructions # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      say ""
      say "=== BranchDb Installation Complete ===", :green
      say ""
      say "Next steps:", :yellow
      say ""
      say "1. Update your config/database.yml to use dynamic database names:"
      say ""
      say "   development:"
      say "     database: <%= BranchDb.database_name('#{app_name}_development') %>"
      say ""
      say "   test:"
      say "     database: <%= BranchDb.database_name('#{app_name}_test') %>"
      say ""
      say "2. Initialize your database:"
      say "   rails db:prepare          # Creates and clones from main"
      say ""
      say "3. Other available tasks:"
      say "   rails db:branch:list      # List all branch databases"
      say "   rails db:branch:purge     # Remove all branch databases (keeps main/current)"
      say "   rails db:branch:prune     # Remove databases for deleted git branches"
      say ""
    end

    private

    def app_name
      Rails.application.class.module_parent_name.underscore
    end
  end
end
