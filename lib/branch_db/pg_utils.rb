require "shellwords"

module BranchDb
  module PgUtils
    PG_TOOLS = %w[psql pg_dump dropdb].freeze

    private

    def psql_flags
      host = config[:host].to_s.shellescape
      port = config[:port].to_s.shellescape
      username = config[:username].to_s.shellescape

      "-h #{host} -p #{port} -U #{username}"
    end

    def pg_env
      { "PGPASSWORD" => config[:password].to_s }
    end

    def list_databases_cmd
      "psql #{psql_flags} -lqt | cut -d \\| -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
    end

    def check_pg_tools!(*tools)
      tools = PG_TOOLS if tools.empty?

      tools.each do |tool|
        unless system("which #{tool} > /dev/null 2>&1")
          raise Error, "PostgreSQL tool '#{tool}' not found in PATH. Please install PostgreSQL client tools."
        end
      end
    end
  end
end
