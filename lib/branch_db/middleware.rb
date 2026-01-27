module BranchDb
  class Middleware
    def initialize(app)
      @app = app
      @current_branch = Naming.current_branch
    end

    def call(env)
      check_branch_change
      @app.call(env)
    end

    private

    def check_branch_change
      branch = Naming.current_branch
      return if branch.empty? || branch == @current_branch

      @current_branch = branch
      prepare_databases
    end

    def prepare_databases
      reload_database_configurations
      db_configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
      db_configs.each { |db_config| Preparer.new(db_config).prepare_if_needed }
      reconnect_databases(db_configs)
    rescue ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.error "[branch_db] Could not connect to Postgres: #{e.message}"
    end

    def reload_database_configurations
      new_configs = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration)
      ActiveRecord::Base.configurations = new_configs
    end

    def reconnect_databases(db_configs)
      ActiveRecord::Base.connection_handler.clear_all_connections!
      db_configs.each { |db_config| ActiveRecord::Base.establish_connection(db_config) }
    end
  end
end
