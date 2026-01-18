RSpec.describe BranchDb::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default main_branch to main" do
      expect(config.main_branch).to eq("main")
    end

    it "sets default max_branch_length to 33" do
      expect(config.max_branch_length).to eq(33)
    end

    it "sets default development_suffix to _development" do
      expect(config.development_suffix).to eq("_development")
    end

    it "sets default test_suffix to _test" do
      expect(config.test_suffix).to eq("_test")
    end
  end

  describe "#main_branch=" do
    it "allows setting a custom main branch" do
      config.main_branch = "master"
      expect(config.main_branch).to eq("master")
    end
  end

  describe "#max_branch_length=" do
    it "allows setting a custom max branch length" do
      config.max_branch_length = 20
      expect(config.max_branch_length).to eq(20)
    end
  end

  describe "#development_suffix=" do
    it "allows setting a custom development suffix" do
      config.development_suffix = "_dev"
      expect(config.development_suffix).to eq("_dev")
    end
  end

  describe "#test_suffix=" do
    it "allows setting a custom test suffix" do
      config.test_suffix = "_testing"
      expect(config.test_suffix).to eq("_testing")
    end
  end
end
