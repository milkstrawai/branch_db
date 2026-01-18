module BranchDb
  class Configuration
    attr_accessor :main_branch, :max_branch_length, :development_suffix, :test_suffix

    def initialize
      @main_branch = "main"
      @max_branch_length = 33
      @development_suffix = "_development"
      @test_suffix = "_test"
    end
  end
end
