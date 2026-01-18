require_relative "branch_db/version"
require_relative "branch_db/configuration"
require_relative "branch_db/git_utils"
require_relative "branch_db/naming"
require_relative "branch_db/pg_utils"
require_relative "branch_db/logging"
require_relative "branch_db/cloner"
require_relative "branch_db/cleaner"
require_relative "branch_db/preparer"
require_relative "branch_db/railtie" if defined?(Rails::Railtie)

module BranchDb
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def database_name(base_name)
      Naming.database_name(base_name)
    end

    def main_database_name(base_name)
      Naming.main_database_name(base_name)
    end
  end
end
