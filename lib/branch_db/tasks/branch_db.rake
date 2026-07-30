def db_configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).select { |c| c.adapter == "postgresql" }

def cleaner_for(db_config) = BranchDb::Cleaner.new(db_config.configuration_hash, prefix: false, name: db_config.name)

def inspector_for(config) = BranchDb::Inspector.new(config.configuration_hash, prefix: false, name: config.name)

namespace :db do
  namespace :branch do
    desc "List all branch databases"
    task list: :environment do
      next if BranchDb.skip_for_env?(Rails.env)

      db_configs.each { cleaner_for(_1).list_branch_databases }
    end

    desc "Remove all branch databases (keeps main and current branch). Set FORCE=1 to skip confirmation."
    task purge: :environment do
      next if BranchDb.skip_for_env?(Rails.env)

      db_configs.each { cleaner_for(_1).purge(confirm: ENV["FORCE"] != "1") }
    end

    desc "Remove databases for branches that no longer exist in git. Set FORCE=1 to skip confirmation."
    task prune: :environment do
      next if BranchDb.skip_for_env?(Rails.env)

      db_configs.each { cleaner_for(_1).prune(confirm: ENV["FORCE"] != "1") }
    end

    desc "Ensure branch database exists (used by db:prepare enhancement)"
    task ensure_cloned: :environment do
      next if BranchDb.skip_for_env?(Rails.env)
      next unless Rails.env.development?

      db_configs.each { BranchDb::Preparer.new(_1).prepare_if_needed }
    rescue ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad => e
      abort "❌ Could not connect to Postgres: #{e.message}"
    end

    desc "Show current branch database info (branch, parent, database name, size)"
    task info: :environment do
      next if BranchDb.skip_for_env?(Rails.env)

      db_configs.each { inspector_for(_1).report }
    end
  end
end

# Enhance Rails' db:prepare to clone from parent branch when needed
Rake::Task["db:prepare"].enhance(["db:branch:ensure_cloned"])
