def db_configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)

def cleaner_for(db_config) = BranchDb::Cleaner.new(db_config.configuration_hash, prefix: false, name: db_config.name)

namespace :db do
  namespace :branch do
    desc "List all branch databases"
    task list: :environment do
      db_configs.each { cleaner_for(_1).list_branch_databases }
    end

    desc "Remove all branch databases (keeps main and current branch)"
    task purge: :environment do
      db_configs.each { cleaner_for(_1).purge }
    end

    desc "Remove databases for branches that no longer exist in git"
    task prune: :environment do
      db_configs.each { cleaner_for(_1).prune }
    end

    desc "Ensure branch database exists (used by db:prepare enhancement)"
    task ensure_cloned: :environment do
      next unless Rails.env.development?

      db_configs.each { BranchDb::Preparer.new(_1).prepare_if_needed }
    rescue ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad => e
      abort "❌ Could not connect to Postgres: #{e.message}"
    end
  end
end

# Enhance Rails' db:prepare to clone from parent branch when needed
Rake::Task["db:prepare"].enhance(["db:branch:ensure_cloned"])
