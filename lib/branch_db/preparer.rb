module BranchDb
  # Checks if database needs initialization and triggers cloning if needed.
  # Used by the db:prepare rake task enhancement.
  class Preparer
    include Logging

    attr_reader :db_config, :output

    def initialize(db_config, output: $stdout)
      @db_config = db_config
      @output = output
    end

    def prepare_if_needed
      log "📦 Checking database#{db_label}..."

      unless needs_cloning?
        log "✅ Database '#{config[:database]}' ready."
        return
      end

      attempt_clone
    end

    private

    def config
      db_config.configuration_hash
    end

    def db_label
      db_config.name == "primary" ? "" : " (#{db_config.name})"
    end

    def needs_cloning?
      establish_connection
      !ActiveRecord::Base.connection.table_exists?("schema_migrations")
    rescue ActiveRecord::NoDatabaseError
      true
    end

    def establish_connection
      ActiveRecord::Base.establish_connection(db_config)
    end

    def attempt_clone
      cloner = Cloner.new(config, output:)

      if cloner.target_db == cloner.source_db
        log_indented "On main branch. Deferring to db:prepare..."
      elsif cloner.source_exists?
        cloner.clone
      else
        log_indented "Source database not found. Deferring to db:prepare..."
      end
    end
  end
end
