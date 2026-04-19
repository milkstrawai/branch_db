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

    context "when BRANCH_DB_DATABASE_DEVELOPMENT is set" do
      around do |example|
        original = ENV.fetch("BRANCH_DB_DATABASE_DEVELOPMENT", nil)
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = "my_prod"
        example.run
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = original
      end

      it "returns the override for a development base name" do
        expect(described_class.database_name("myapp_development")).to eq("my_prod")
      end

      it "does not apply to test base names" do
        expect(described_class.database_name("myapp_test")).to eq("myapp_test_feature_auth")
      end

      it "does not apply to unrelated base names" do
        expect(described_class.database_name("myapp")).to eq("myapp_feature_auth")
      end
    end

    context "when BRANCH_DB_DATABASE_TEST is set" do
      around do |example|
        original = ENV.fetch("BRANCH_DB_DATABASE_TEST", nil)
        ENV["BRANCH_DB_DATABASE_TEST"] = "shared_test_db"
        example.run
        ENV["BRANCH_DB_DATABASE_TEST"] = original
      end

      it "returns the override for a test base name" do
        expect(described_class.database_name("myapp_test")).to eq("shared_test_db")
      end

      it "does not apply to development base names" do
        expect(described_class.database_name("myapp_development")).to eq("myapp_development_feature_auth")
      end
    end

    context "when override env var is an empty string" do
      around do |example|
        original = ENV.fetch("BRANCH_DB_DATABASE_DEVELOPMENT", nil)
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = ""
        example.run
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = original
      end

      it "falls back to the branch-suffixed name" do
        expect(described_class.database_name("myapp_development")).to eq("myapp_development_feature_auth")
      end
    end

    context "with custom configured suffixes" do
      around do |example|
        original = ENV.fetch("BRANCH_DB_DATABASE_DEVELOPMENT", nil)
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = "custom_override"
        example.run
        ENV["BRANCH_DB_DATABASE_DEVELOPMENT"] = original
      end

      it "honors non-default development_suffix" do
        BranchDb.configure { |c| c.development_suffix = "_dev" }
        expect(described_class.database_name("myapp_dev")).to eq("custom_override")
      end
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
