RSpec.describe BranchDb::Cloner do
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
  let(:cloner) { described_class.new(config, output: output) }

  before do
    stub_branch_suffix
    stub_pg_tools_available(cloner)
  end

  describe "#initialize" do
    it "accepts a hash config" do
      expect(cloner.config).to eq(config)
    end

    it "extracts configuration_hash from ActiveRecord config objects" do
      ar_config = double(configuration_hash: config)
      expect(described_class.new(ar_config, output: output).config).to eq(config)
    end
  end

  describe "#target_db" do
    it "returns the database from config" do
      expect(cloner.target_db).to eq("myapp_development_feature_auth")
    end
  end

  describe "#base_name" do
    it "removes branch suffix from target database" do
      expect(cloner.base_name).to eq("myapp_development")
    end

    it "returns target_db when no branch suffix" do
      stub_branch_suffix("")
      expect(cloner.base_name).to eq("myapp_development_feature_auth")
    end
  end

  describe "#source_db" do
    context "when parent is main branch" do
      before { stub_parent_branch("main") }

      it "returns the main branch database name" do
        expect(cloner.source_db).to eq("myapp_development_main")
      end

      it "uses configured main branch" do
        BranchDb.configure { |c| c.main_branch = "master" }
        stub_parent_branch("master")
        expect(cloner.source_db).to eq("myapp_development_master")
      end
    end

    context "when parent database exists" do
      before do
        stub_parent_branch("feature-parent")
        allow(cloner).to receive(:system)
          .with({ "PGPASSWORD" => "secret" }, "bash", "-c", /grep -qx myapp_development_feature_parent/)
          .and_return(true)
      end

      it "returns the parent branch database name" do
        expect(cloner.source_db).to eq("myapp_development_feature_parent")
      end
    end

    context "when parent database does not exist" do
      before do
        stub_parent_branch("feature-parent")
        allow(cloner).to receive(:system)
          .with({ "PGPASSWORD" => "secret" }, "bash", "-c", /grep -qx myapp_development_feature_parent/)
          .and_return(false)
      end

      it "falls back to main branch database" do
        expect(cloner.source_db).to eq("myapp_development_main")
      end
    end

    context "when parent has special characters" do
      before do
        stub_parent_branch("feature/with-slashes")
        allow(cloner).to receive(:system)
          .with({ "PGPASSWORD" => "secret" }, "bash", "-c", /grep -qx myapp_development_feature_with_slashes/)
          .and_return(true)
      end

      it "sanitizes the parent branch name" do
        expect(cloner.source_db).to eq("myapp_development_feature_with_slashes")
      end
    end
  end

  describe "#source_exists?" do
    before { stub_parent_branch("main") }

    it "returns true when source database exists" do
      allow(cloner).to receive(:system)
        .with({ "PGPASSWORD" => "secret" }, "bash", "-c", /psql.*grep -qx myapp_development_main/)
        .and_return(true)

      expect(cloner.send(:source_exists?)).to be true
    end

    it "returns false when source database does not exist" do
      allow(cloner).to receive(:system)
        .with({ "PGPASSWORD" => "secret" }, "bash", "-c", /psql.*grep -qx myapp_development_main/)
        .and_return(false)

      expect(cloner.send(:source_exists?)).to be false
    end
  end

  describe "#check_pg_tools!" do
    it "raises error when psql is not found" do
      allow(cloner).to receive(:system).with("which psql > /dev/null 2>&1").and_return(false)
      expect { cloner.send(:check_pg_tools!, :psql, :pg_dump) }.to raise_error(BranchDb::Error, /psql.*not found/)
    end

    it "raises error when pg_dump is not found" do
      allow(cloner).to receive(:system).with("which pg_dump > /dev/null 2>&1").and_return(false)
      expect { cloner.send(:check_pg_tools!, :psql, :pg_dump) }.to raise_error(BranchDb::Error, /pg_dump.*not found/)
    end

    it "does not raise when all tools are available" do
      expect { cloner.send(:check_pg_tools!, :psql, :pg_dump) }.not_to raise_error
    end
  end

  describe "#clone" do
    before { stub_parent_branch("main") }

    context "when cloning successfully" do
      before { allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create) }

      it "clones from source to target" do
        allow(cloner).to receive(:system).and_return(true)
        cloner.clone
        expect(output.string).to include("Cloning myapp_development_main", "Database cloned successfully")
      end
    end

    context "when target database already exists" do
      before do
        call_count = 0
        allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create) do
          call_count += 1
          raise ActiveRecord::DatabaseAlreadyExists if call_count == 1
        end
        allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:drop)
        allow(cloner).to receive(:system).and_return(true)
        cloner.clone
      end

      it "recreates database" do
        expect(output.string).to include("already exists. Recreating")
      end

      it "drops the existing database" do
        expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:drop).once
      end
    end

    context "when clone operation fails" do
      before do
        allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create)
        allow(cloner).to receive(:system)
          .with({ "PGPASSWORD" => "secret" }, "bash", "-c", anything, %i[out err] => File::NULL)
          .and_return(false)
      end

      it "raises error" do
        expect { cloner.clone }.to raise_error(BranchDb::Error, /Clone failed/)
      end
    end
  end
end
