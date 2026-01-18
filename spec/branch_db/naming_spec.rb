RSpec.describe BranchDb::Naming do
  describe ".sanitize_branch" do
    it "replaces non-alphanumeric characters with underscores" do
      expect(described_class.sanitize_branch("feature/auth-system")).to eq("feature_auth_system")
    end

    it "preserves underscores" do
      expect(described_class.sanitize_branch("feature_auth")).to eq("feature_auth")
    end

    it "handles empty strings" do
      expect(described_class.sanitize_branch("")).to eq("")
    end
  end

  describe ".branch_suffix" do
    before do
      allow(described_class).to receive(:current_branch).and_return("feature-auth")
    end

    it "returns sanitized branch with underscore prefix" do
      expect(described_class.branch_suffix).to eq("_feature_auth")
    end

    it "truncates branch names longer than max_branch_length" do
      BranchDb.configure { |c| c.max_branch_length = 10 }
      allow(described_class).to receive(:current_branch).and_return("this-is-a-very-long-branch-name")
      expect(described_class.branch_suffix).to eq("_this_is_a_")
    end

    it "returns empty string when no branch" do
      allow(described_class).to receive(:current_branch).and_return("")
      expect(described_class.branch_suffix).to eq("")
    end
  end

  describe ".database_name" do
    before do
      allow(described_class).to receive(:branch_suffix).and_return("_feature_auth")
    end

    it "appends branch suffix to base name" do
      expect(described_class.database_name("myapp_development")).to eq("myapp_development_feature_auth")
    end
  end

  describe ".main_database_name" do
    it "appends main branch name to base name" do
      expect(described_class.main_database_name("myapp_development")).to eq("myapp_development_main")
    end

    it "uses configured main branch" do
      BranchDb.configure { |c| c.main_branch = "master" }
      expect(described_class.main_database_name("myapp_development")).to eq("myapp_development_master")
    end
  end

  describe ".parent_database_name" do
    it "builds database name from parent branch" do
      allow(described_class).to receive(:parent_branch).and_return("feature-parent")
      expect(described_class.parent_database_name("myapp_development")).to eq("myapp_development_feature_parent")
    end

    it "sanitizes the parent branch name" do
      allow(described_class).to receive(:parent_branch).and_return("feature/with-slashes")
      expect(described_class.parent_database_name("myapp_development")).to eq("myapp_development_feature_with_slashes")
    end
  end
end
