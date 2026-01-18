module BranchDb
  module Logging
    PREFIX = "[branch_db]".freeze

    private

    def log(message)
      output.puts prefix? ? "#{PREFIX} #{message}" : message
    end

    def log_indented(message)
      output.puts prefix? ? "#{PREFIX}    #{message}" : "   #{message}"
    end

    def prefix? = @prefix != false
  end
end
