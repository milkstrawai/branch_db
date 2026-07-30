require "open3"

module BranchDb
  # Prints diagnostic information for the current branch database:
  # branch name, parent branch, database name, size and clone source status.
  # Read-only — never modifies any database.
  class Inspector
    include PgUtils
    include Logging

    attr_reader :config, :output, :name

    def initialize(config, output: $stdout, prefix: true, name: nil)
      @config = config.is_a?(Hash) ? config : config.configuration_hash
      @output = output
      @prefix = prefix
      @name = name
    end

    def report
      check_pg_tools!(:psql)
      log "Branch:   #{BranchDb::Naming.current_branch} (parent: #{BranchDb::Naming.parent_branch})"
      log "Database#{db_label}: #{target_db}"
      size = database_size(target_db)
      log_indented "Size:     #{size || "n/a (database does not exist)"}"
      report_clone_source
    end

    private

    def target_db = config[:database]

    def report_clone_source
      if parent_db == main_db
        log_indented "Parent:   #{main_db} (main branch#{presence_suffix(main_db)})"
      elsif (size = database_size(parent_db))
        log_indented "Parent:   #{parent_db} (exists, #{size})"
      else
        log_indented "Parent:   #{parent_db} (missing — would clone from #{main_db})"
      end
    end

    def parent_db = BranchDb::Naming.parent_database_name(base_name)
    def main_db = BranchDb::Naming.main_database_name(base_name)

    def base_name
      suffix = BranchDb::Naming.branch_suffix
      return target_db if suffix.empty?

      target_db.sub(/#{Regexp.escape(suffix)}\z/, "")
    end

    def presence_suffix(db_name)
      size = database_size(db_name)
      size ? ", #{size}" : ", missing"
    end

    # Returns a human-readable size ("42 MB") or nil when the database
    # does not exist — pg_database_size() fails for unknown databases,
    # so a single query doubles as an existence check.
    def database_size(db_name)
      query = "SELECT pg_size_pretty(pg_database_size('#{db_name.gsub("'", "''")}'))"
      stdout, status = Open3.capture2(pg_env, "bash", "-c",
                                      "psql #{psql_flags} -d postgres -tAc \"#{query}\" 2>/dev/null")
      return nil unless status.success?

      size = stdout.strip
      size.empty? ? nil : size
    end

    def db_label = name && name != "primary" ? " (#{name})" : ""
  end
end
