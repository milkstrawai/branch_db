RSpec.describe BranchDb::Inspector do
  let(:config) do
    {
      database: "myapp_development_feature_auth",
      host: "localhost",
      port: 5432,
      username: "postgres",
      password: "secret"
    }
  end
  let(:output) { StringIO.new }
  let(:inspector) { described_class.new(config, output: output) }

  before do
    stub_branch_suffix
    stub_parent_branch("develop")
    stub_pg_tools_available(inspector)
    allow(BranchDb::Naming).to receive(:current_branch).and_return("feature/auth")
  end

  def stub_size(db_name, size)
    query = "SELECT pg_size_pretty(pg_database_size('#{db_name}'))"
    status = instance_double(Process::Status, success?: !size.nil?)
    allow(Open3).to receive(:capture2)
      .with({ "PGPASSWORD" => "secret" }, "bash", "-c", a_string_including(query))
      .and_return(["#{size}\n", status])
  end

  describe "#initialize" do
    it "accepts a hash config" do
      expect(inspector.config).to eq(config)
    end

    it "extracts configuration_hash from ActiveRecord config objects" do
      ar_config = double(configuration_hash: config)
      expect(described_class.new(ar_config, output: output).config).to eq(config)
    end
  end

  describe "#report" do
    before do
      stub_size("myapp_development_feature_auth", "42 MB")
      stub_size("myapp_development_develop", "38 MB")
    end

    it "prints the current branch and its parent" do
      inspector.report
      expect(output.string).to include("Branch:   feature/auth (parent: develop)")
    end

    it "prints the current branch database name" do
      inspector.report
      expect(output.string).to include("Database: myapp_development_feature_auth")
    end

    it "prints the current branch database size" do
      inspector.report
      expect(output.string).to include("Size:     42 MB")
    end

    it "raises when psql is not available" do
      allow(inspector).to receive(:system).with("which psql > /dev/null 2>&1").and_return(false)
      expect { inspector.report }.to raise_error(BranchDb::Error, /psql/)
    end

    context "when the branch database does not exist yet" do
      before { stub_size("myapp_development_feature_auth", nil) }

      it "prints a placeholder instead of the size" do
        inspector.report
        expect(output.string).to include("Size:     n/a (database does not exist)")
      end
    end

    context "when the parent database exists" do
      it "prints the parent database with its size" do
        inspector.report
        expect(output.string).to include("Parent:   myapp_development_develop (exists, 38 MB)")
      end
    end

    context "when the parent database is missing" do
      before { stub_size("myapp_development_develop", nil) }

      it "prints the main database as the clone fallback" do
        inspector.report
        expect(output.string)
          .to include("Parent:   myapp_development_develop (missing — would clone from myapp_development_main)")
      end
    end

    context "when the parent branch is the main branch" do
      before do
        stub_parent_branch("main")
        stub_size("myapp_development_main", "100 MB")
      end

      it "reports the main database with its size" do
        inspector.report
        expect(output.string).to include("Parent:   myapp_development_main (main branch, 100 MB)")
      end

      it "reports the main database as missing when it does not exist" do
        stub_size("myapp_development_main", nil)
        inspector.report
        expect(output.string).to include("Parent:   myapp_development_main (main branch, missing)")
      end
    end

    context "when on the main branch itself" do
      before do
        stub_branch_suffix("_main")
        stub_parent_branch("main")
        stub_size("myapp_development_main", "100 MB")
      end

      let(:config) { super().merge(database: "myapp_development_main") }

      it "reports the main database as its own clone source" do
        inspector.report
        expect(output.string).to include("Parent:   myapp_development_main (main branch, 100 MB)")
      end
    end

    context "when the database name has no branch suffix" do
      before do
        stub_branch_suffix("")
        stub_size("myapp_development", "10 MB")
        stub_size("myapp_development_develop", "38 MB")
      end

      let(:config) { super().merge(database: "myapp_development") }

      it "uses the database name as the base name" do
        inspector.report
        expect(output.string).to include("Parent:   myapp_development_develop (exists, 38 MB)")
      end
    end

    context "with prefix: true (default)" do
      it "outputs with [branch_db] prefix" do
        inspector.report
        expect(output.string).to include("[branch_db]")
      end
    end

    context "with prefix: false" do
      let(:inspector) { described_class.new(config, output: output, prefix: false) }

      it "outputs without [branch_db] prefix" do
        inspector.report
        expect(output.string).not_to include("[branch_db]")
      end
    end

    context "with name: for secondary database" do
      let(:inspector) { described_class.new(config, output: output, name: "cache") }

      it "includes database name in output" do
        inspector.report
        expect(output.string).to include("Database (cache): myapp_development_feature_auth")
      end
    end

    context "with name: primary" do
      let(:inspector) { described_class.new(config, output: output, name: "primary") }

      it "prints the database line without a label" do
        inspector.report
        expect(output.string).to include("Database: myapp_development_feature_auth")
      end

      it "does not include database name in output" do
        inspector.report
        expect(output.string).not_to include("(primary)")
      end
    end
  end

  describe "#database_size" do
    it "escapes single quotes in database names" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture2).and_return(["1 MB\n", status])
      inspector.send(:database_size, "o'brien")
      expect(Open3).to have_received(:capture2)
        .with({ "PGPASSWORD" => "secret" }, "bash", "-c", a_string_including("o''brien"))
    end

    it "returns nil when psql returns empty output" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture2).and_return(["\n", status])
      expect(inspector.send(:database_size, "myapp_development")).to be_nil
    end
  end
end
