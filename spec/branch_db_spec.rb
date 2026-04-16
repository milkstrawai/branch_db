require "active_support/string_inquirer"

RSpec.describe BranchDb do
  it "has a version number" do
    expect(BranchDb::VERSION).not_to be_nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(BranchDb::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.main_branch = "master"
      end

      expect(described_class.configuration.main_branch).to eq("master")
    end
  end

  describe ".database_name" do
    it "delegates to Naming.database_name" do
      allow(BranchDb::Naming).to receive(:database_name).with("myapp_dev").and_return("myapp_dev_feature")
      expect(described_class.database_name("myapp_dev")).to eq("myapp_dev_feature")
    end
  end

  describe ".main_database_name" do
    it "delegates to Naming.main_database_name" do
      allow(BranchDb::Naming).to receive(:main_database_name).with("myapp_dev").and_return("myapp_dev_main")
      expect(described_class.main_database_name("myapp_dev")).to eq("myapp_dev_main")
    end
  end

  describe ".database_override_for_env" do
    around do |example|
      original = ENV.fetch("BRANCH_DB_DATABASE_DEVELOPMENT", nil)
      example.run
      ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = original
    end

    it "returns the env var value for the given environment" do
      ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = "shared_dev"
      expect(described_class.database_override_for_env("development")).to eq("shared_dev")
    end

    it "returns nil when env var is unset" do
      ENV.delete("BRANCH_DB_DATABASE_DEVELOPMENT")
      expect(described_class.database_override_for_env("development")).to be_nil
    end

    it "returns nil when env var is empty" do
      ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = ""
      expect(described_class.database_override_for_env("development")).to be_nil
    end

    it "accepts a symbol" do
      ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = "shared_dev"
      expect(described_class.database_override_for_env(:development)).to eq("shared_dev")
    end
  end

  describe ".overridden_for_env?" do
    around do |example|
      original = ENV.fetch("BRANCH_DB_DATABASE_TEST", nil)
      example.run
      ENV["BRANCH_DB_DATABASE_TEST"] = original
    end

    it "is true when override is set" do
      ENV["BRANCH_DB_DATABASE_TEST"] = "foo"
      expect(described_class.overridden_for_env?("test")).to be true
    end

    it "is false when override is not set" do
      ENV.delete("BRANCH_DB_DATABASE_TEST")
      expect(described_class.overridden_for_env?("test")).to be false
    end
  end

  describe ".skip_for_env?" do
    around do |example|
      original = ENV.fetch("BRANCH_DB_DATABASE_TEST", nil)
      example.run
      ENV["BRANCH_DB_DATABASE_TEST"] = original
    end

    it "returns true and prints a skip message when the override is set" do # rubocop:disable RSpec/MultipleExpectations
      ENV["BRANCH_DB_DATABASE_TEST"] = "foo"
      output = StringIO.new
      expect(described_class.skip_for_env?("test", output:)).to be true
      expect(output.string).to include("Skipping").and include("BRANCH_DB_DATABASE_TEST")
    end

    it "returns false and prints nothing when the override is not set" do # rubocop:disable RSpec/MultipleExpectations
      ENV.delete("BRANCH_DB_DATABASE_TEST")
      output = StringIO.new
      expect(described_class.skip_for_env?("test", output:)).to be false
      expect(output.string).to be_empty
    end

    it "upcases symbol envs in the skip message" do
      ENV["BRANCH_DB_DATABASE_TEST"] = "foo"
      output = StringIO.new
      described_class.skip_for_env?(:test, output:)
      expect(output.string).to include("BRANCH_DB_DATABASE_TEST")
    end

    it "accepts a Rails.env-style ActiveSupport::StringInquirer" do # rubocop:disable RSpec/MultipleExpectations
      ENV["BRANCH_DB_DATABASE_TEST"] = "foo"
      output = StringIO.new
      expect(described_class.skip_for_env?(ActiveSupport::StringInquirer.new("test"), output:)).to be true
      expect(output.string).to include("BRANCH_DB_DATABASE_TEST")
    end
  end
end
