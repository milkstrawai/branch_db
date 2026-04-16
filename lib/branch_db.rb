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
    def configuration = @configuration ||= Configuration.new

    def configure = yield(configuration)

    def database_name(base_name) = Naming.database_name(base_name)

    def main_database_name(base_name) = Naming.main_database_name(base_name)

    def database_override_for_env(env)
      value = ENV.fetch("BRANCH_DB_DATABASE_#{env.to_s.upcase}", nil)
      value if value && !value.empty?
    end

    def overridden_for_env?(env) = !database_override_for_env(env).nil?

    def skip_for_env?(env, output: $stdout)
      return false unless overridden_for_env?(env)

      output.puts "⏭️  Skipping — BRANCH_DB_DATABASE_#{env.to_s.upcase} override in effect."
      true
    end
  end
end
