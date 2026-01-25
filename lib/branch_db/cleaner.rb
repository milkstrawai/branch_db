require "open3"

module BranchDb
  class Cleaner
    include PgUtils
    include Logging

    attr_reader :config, :output, :input, :name

    def initialize(config, output: $stdout, input: $stdin, prefix: true, name: nil)
      @config = config.is_a?(Hash) ? config : config.configuration_hash
      @output = output
      @input = input
      @prefix = prefix
      @name = name
    end

    def list_branch_databases
      all_dbs = all_branch_databases

      if all_dbs.empty?
        log "No branch databases found#{db_label}."
        return []
      end

      log "Found #{all_dbs.size} branch database(s)#{db_label}:"
      all_dbs.each { |db| log "  - #{db}" }
      all_dbs
    end

    def purge(confirm: true)
      delete_databases(deletable_databases, empty_msg: "No old branch databases to purge#{db_label}.",
                                            done_msg: "Purge complete#{db_label}!", confirm:)
    end

    def prune(confirm: true)
      delete_databases(prunable_databases, empty_msg: "No stale branch databases to prune#{db_label}.",
                                           done_msg: "Prune complete#{db_label}!", confirm:)
    end

    private

    def deletable_databases = all_branch_databases.reject { |db| protected_databases.include?(db) }

    def prunable_databases
      existing = BranchDb::Naming.git_branches.map { BranchDb::Naming.sanitize_branch(_1) }
      all_branch_databases.reject { |db| protected_databases.include?(db) || branch_exists?(db, existing) }
    end

    def all_branch_databases = find_databases(dev_prefix) + find_databases(test_prefix)

    def protected_databases
      current_dev = config[:database]
      current_test = current_dev.sub(dev_prefix, test_prefix)

      [
        current_dev,
        current_test,
        "#{dev_prefix}#{BranchDb.configuration.main_branch}",
        "#{test_prefix}#{BranchDb.configuration.main_branch}"
      ]
    end

    def branch_exists?(db, existing_branches)
      prefix = db.start_with?(test_prefix) ? test_prefix : dev_prefix
      existing_branches.include?(db.sub(prefix, ""))
    end

    def delete_databases(to_delete, empty_msg:, done_msg:, confirm:)
      return log(empty_msg) if to_delete.empty?

      display_databases(to_delete)
      return log("Aborted.") if confirm && !user_confirmed?

      to_delete.each { |db| drop_database(db) }
      log done_msg
    end

    def display_databases(databases)
      log "Found #{databases.size} database(s) to remove:"
      databases.each { log "  - #{_1}" }
    end

    def user_confirmed? = (output.print "\nProceed with deletion? [y/N] ") || input.gets&.chomp&.downcase == "y"

    def find_databases(prefix)
      check_pg_tools!(:psql, :dropdb)
      stdout, = Open3.capture2(pg_env, "bash", "-c", "#{list_databases_cmd} | grep ^#{prefix.shellescape}")
      stdout.split("\n").map(&:strip).reject(&:empty?)
    end

    def drop_database(db)
      active = active_connections(db)
      return log "⚠️  Skipping #{db} (#{active} active connection#{"s" if active > 1})" if active.positive?

      dropped = system(pg_env, "bash", "-c", "dropdb #{psql_flags} #{db.shellescape}")
      log dropped ? "✅ Dropped #{db}" : "❌ Failed to drop #{db}"
    end

    def active_connections(db)
      query = "SELECT count(*) FROM pg_stat_activity WHERE datname = '#{db.gsub("'", "''")}'"
      stdout, = Open3.capture2(pg_env, "bash", "-c", "psql #{psql_flags} -d postgres -tAc \"#{query}\"")
      stdout.strip.to_i
    end

    def db_label = name && name != "primary" ? " for #{name}" : ""

    def dev_prefix = "#{base_name}_"

    def test_prefix = "#{base_name.sub(BranchDb.configuration.development_suffix, BranchDb.configuration.test_suffix)}_"

    def base_name
      suffix = BranchDb::Naming.branch_suffix
      suffix.empty? ? config[:database] : config[:database].sub(/#{Regexp.escape(suffix)}\z/, "")
    end
  end
end
