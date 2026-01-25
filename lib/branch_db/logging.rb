module BranchDb
  module Logging
    PREFIX = "[branch_db]".freeze

    private

    def log(message) = output.puts prefix? ? "#{PREFIX} #{message}" : message

    def log_indented(message) = output.puts prefix? ? "#{PREFIX}    #{message}" : "   #{message}"

    def prefix? = @prefix != false
  end
end
