module BranchDb
  class Cloner
    include PgUtils
    include Logging

    attr_reader :config, :output

    def initialize(config, output: $stdout)
      @config = config.is_a?(Hash) ? config : config.configuration_hash
      @output = output
    end

    def clone
      log "📦 Cloning #{source_db} → #{target_db}..."
      create_or_recreate_database
      transfer_data
    end

    def source_exists?
      check_pg_tools!(:psql, :pg_dump)
      database_exists?(source_db)
    end

    def source_db = @source_db ||= determine_source_db

    def target_db = config[:database]

    private

    def determine_source_db
      parent_db = BranchDb::Naming.parent_database_name(base_name)
      main_db = "#{base_name}_#{BranchDb.configuration.main_branch}"

      return main_db if parent_db == main_db

      check_pg_tools!(:psql, :pg_dump)
      database_exists?(parent_db) ? parent_db : main_db
    end

    def base_name
      suffix = BranchDb::Naming.branch_suffix
      return target_db if suffix.empty?

      target_db.sub(/#{Regexp.escape(suffix)}\z/, "")
    end

    def database_exists?(db_name)
      check_cmd = "#{list_databases_cmd} | grep -qx #{db_name.shellescape}"
      system(pg_env, "bash", "-c", check_cmd)
    end

    def create_or_recreate_database
      ActiveRecord::Tasks::DatabaseTasks.create(config)
      log_indented "Created database '#{target_db}'"
    rescue ActiveRecord::DatabaseAlreadyExists
      log_indented "Database '#{target_db}' already exists. Recreating..."
      ActiveRecord::Tasks::DatabaseTasks.drop(config)
      ActiveRecord::Tasks::DatabaseTasks.create(config)
    end

    def transfer_data
      dump_cmd = "pg_dump #{psql_flags} --no-owner --no-acl #{source_db.shellescape}"
      restore_cmd = "psql #{psql_flags} #{target_db.shellescape}"
      full_command = "set -o pipefail; #{dump_cmd} | #{restore_cmd}"

      log_indented "Transferring data..."

      unless system(pg_env, "bash", "-c", full_command, %i[out err] => File::NULL)
        raise Error, "Clone failed! Check PostgreSQL connection."
      end

      log "✅ Database cloned successfully!"
    end
  end
end
