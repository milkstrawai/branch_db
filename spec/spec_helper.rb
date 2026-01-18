require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_group "Core", "lib/branch_db"
  add_group "Generators", "lib/generators"

  enable_coverage :branch

  minimum_coverage line: 100, branch: 90
end

require "active_record"
require "rake"
require "pg"
require "branch_db"

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    BranchDb.instance_variable_set(:@configuration, nil)
    BranchDb::Naming.reset_parent_cache!
  end
end
