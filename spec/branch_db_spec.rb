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
end
