RSpec.describe BranchDb::Cleaner do
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
  let(:input) { StringIO.new }
  let(:cleaner) { described_class.new(config, output: output, input: input) }

  before do
    stub_branch_suffix
    stub_pg_tools_available(cleaner)
  end

  describe "#initialize" do
    it "accepts a hash config" do
      expect(cleaner.config).to eq(config)
    end

    it "extracts configuration_hash from ActiveRecord config objects" do
      ar_config = double(configuration_hash: config)
      expect(described_class.new(ar_config, output: output, input: input).config).to eq(config)
    end

    context "with prefix: false" do
      let(:cleaner) { described_class.new(config, output: output, input: input, prefix: false) }

      before { allow(Open3).to receive(:capture2).and_return(["", double]) }

      it "outputs without [branch_db] prefix" do
        cleaner.list_branch_databases
        expect(output.string).not_to include("[branch_db]")
      end
    end

    context "with name: for secondary database" do
      let(:cleaner) { described_class.new(config, output: output, input: input, name: "cache") }

      before { allow(Open3).to receive(:capture2).and_return(["", double]) }

      it "includes database name in output" do
        cleaner.list_branch_databases
        expect(output.string).to include("for cache")
      end
    end

    context "with name: primary" do
      let(:cleaner) { described_class.new(config, output: output, input: input, name: "primary") }

      before { allow(Open3).to receive(:capture2).and_return(["", double]) }

      it "does not include database name in output" do
        cleaner.list_branch_databases
        expect(output.string).not_to include("for primary")
      end
    end
  end

  describe "#base_name" do
    it "removes branch suffix from database name" do
      expect(cleaner.send(:base_name)).to eq("myapp_development")
    end

    it "returns database name unchanged when no branch suffix" do
      stub_branch_suffix("")
      expect(cleaner.send(:base_name)).to eq("myapp_development_feature_auth")
    end
  end

  describe "#protected_databases" do
    it "includes current dev and test databases" do
      expect(cleaner.protected_databases).to include("myapp_development_feature_auth", "myapp_test_feature_auth")
    end

    it "includes main dev and test databases" do
      expect(cleaner.protected_databases).to include("myapp_development_main", "myapp_test_main")
    end

    it "uses configured main branch" do
      BranchDb.configure { |c| c.main_branch = "master" }
      expect(cleaner.protected_databases).to include("myapp_development_master", "myapp_test_master")
    end

    it "uses configured development and test suffixes" do
      BranchDb.configure { |c| c.development_suffix = "_dev" }
      expect(cleaner.protected_databases).to include("myapp_development_feature_auth")
    end
  end

  describe "#check_pg_tools!" do
    it "raises error when psql is not found" do
      allow(cleaner).to receive(:system).with("which psql > /dev/null 2>&1").and_return(false)
      expect { cleaner.send(:check_pg_tools!, :psql, :dropdb) }.to raise_error(BranchDb::Error, /psql.*not found/)
    end

    it "raises error when dropdb is not found" do
      allow(cleaner).to receive(:system).with("which dropdb > /dev/null 2>&1").and_return(false)
      expect { cleaner.send(:check_pg_tools!, :psql, :dropdb) }.to raise_error(BranchDb::Error, /dropdb.*not found/)
    end
  end

  describe "#list_branch_databases" do
    context "when no databases found" do
      before { allow(Open3).to receive(:capture2).and_return(["", double]) }

      it "returns empty array" do
        expect(cleaner.list_branch_databases).to eq([])
      end

      it "outputs no databases message" do
        cleaner.list_branch_databases
        expect(output.string).to include("No branch databases found")
      end
    end

    context "when databases exist" do
      before do
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /grep.*myapp_development_/)
          .and_return(["myapp_development_main\nmyapp_development_feature\n", double])
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /grep.*myapp_test_/)
          .and_return(["myapp_test_main\n", double])
      end

      it "returns found databases" do
        expected = %w[myapp_development_main myapp_development_feature myapp_test_main]
        expect(cleaner.list_branch_databases).to eq(expected)
      end

      it "outputs count message" do
        cleaner.list_branch_databases
        expect(output.string).to include("Found 3 branch database(s)")
      end
    end
  end

  describe "#purge" do
    before do
      dev_dbs = "myapp_development_main\nmyapp_development_old_branch\nmyapp_development_feature_auth\n"
      test_dbs = "myapp_test_main\nmyapp_test_old_branch\nmyapp_test_feature_auth\n"
      allow(Open3).to receive(:capture2)
        .with(anything, "bash", "-c", /grep.*myapp_development_/)
        .and_return([dev_dbs, double])
      allow(Open3).to receive(:capture2)
        .with(anything, "bash", "-c", /grep.*myapp_test_/)
        .and_return([test_dbs, double])
    end

    it "does nothing when no databases to delete" do
      allow(Open3).to receive(:capture2).and_return(["", double])
      cleaner.purge
      expect(output.string).to include("No old branch databases to purge")
    end

    context "when listing databases to delete" do
      before do
        input.string = "n\n"
        cleaner.purge
      end

      it "shows count of databases to remove" do
        expect(output.string).to include("Found 2 database(s) to remove")
      end

      it "includes old branch databases" do
        expect(output.string).to include("myapp_development_old_branch", "myapp_test_old_branch")
      end

      it "excludes protected databases" do
        expect(output.string).not_to include("myapp_development_main")
      end
    end

    it "aborts when user declines" do
      input.string = "n\n"
      cleaner.purge
      expect(output.string).to include("Aborted")
    end

    it "drops databases when user confirms" do
      input.string = "y\n"
      allow(Open3).to receive(:capture2).with(anything, "bash", "-c", /pg_stat_activity/).and_return(["0", double])
      allow(cleaner).to receive(:system).and_return(true)

      cleaner.purge

      expect(output.string).to include("Purge complete!")
    end

    context "with active connections on a database" do
      before do
        input.string = "y\n"
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /pg_stat_activity.*myapp_development_old_branch/)
          .and_return(["2", double])
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /pg_stat_activity.*myapp_test_old_branch/)
          .and_return(["0", double])
        allow(cleaner).to receive(:system).and_return(true)
        cleaner.purge
      end

      it "skips databases with active connections" do
        expect(output.string).to include("Skipping myapp_development_old_branch (2 active connections)")
      end
    end

    context "when confirm: false" do
      before do
        allow(Open3).to receive(:capture2).with(anything, "bash", "-c", /pg_stat_activity/).and_return(["0", double])
        allow(cleaner).to receive(:system).and_return(true)
        cleaner.purge(confirm: false)
      end

      it "skips confirmation prompt" do
        expect(output.string).not_to include("Proceed with deletion?")
      end

      it "completes purge" do
        expect(output.string).to include("Purge complete!")
      end
    end

    it "reports failed drops" do
      input.string = "y\n"
      allow(Open3).to receive(:capture2).with(anything, "bash", "-c", /pg_stat_activity/).and_return(["0", double])
      allow(cleaner).to receive(:system).with(anything, "bash", "-c", /^dropdb/).and_return(false)

      cleaner.purge

      expect(output.string).to include("Failed to drop")
    end
  end

  describe "#prune" do
    before do
      dev_dbs = "myapp_development_main\nmyapp_development_deleted_branch\nmyapp_development_feature_auth\n"
      test_dbs = "myapp_test_main\nmyapp_test_deleted_branch\nmyapp_test_feature_auth\n"
      allow(Open3).to receive(:capture2)
        .with(anything, "bash", "-c", /grep.*myapp_development_/)
        .and_return([dev_dbs, double])
      allow(Open3).to receive(:capture2)
        .with(anything, "bash", "-c", /grep.*myapp_test_/)
        .and_return([test_dbs, double])
      allow(BranchDb::Naming).to receive(:git_branches).and_return(%w[main feature-auth])
    end

    it "does nothing when no stale databases" do
      allow(BranchDb::Naming).to receive(:git_branches).and_return(%w[main feature-auth deleted-branch])
      cleaner.prune
      expect(output.string).to include("No stale branch databases to prune")
    end

    context "when listing databases to prune" do
      before do
        input.string = "n\n"
        cleaner.prune
      end

      it "shows count of databases to remove" do
        expect(output.string).to include("Found 2 database(s) to remove")
      end

      it "includes databases for deleted branches" do
        expect(output.string).to include("myapp_development_deleted_branch", "myapp_test_deleted_branch")
      end

      it "excludes dev databases for existing branches" do
        expect(output.string).not_to include("myapp_development_feature_auth")
      end

      it "excludes test databases for existing branches" do
        expect(output.string).not_to include("myapp_test_feature_auth")
      end

      it "excludes main dev database" do
        expect(output.string).not_to include("myapp_development_main")
      end

      it "excludes main test database" do
        expect(output.string).not_to include("myapp_test_main")
      end
    end

    it "aborts when user declines" do
      input.string = "n\n"
      cleaner.prune
      expect(output.string).to include("Aborted")
    end

    it "drops databases when user confirms" do
      input.string = "y\n"
      allow(Open3).to receive(:capture2).with(anything, "bash", "-c", /pg_stat_activity/).and_return(["0", double])
      allow(cleaner).to receive(:system).and_return(true)

      cleaner.prune

      expect(output.string).to include("Prune complete!")
    end

    context "when confirm: false" do
      before do
        allow(Open3).to receive(:capture2).with(anything, "bash", "-c", /pg_stat_activity/).and_return(["0", double])
        allow(cleaner).to receive(:system).and_return(true)
        cleaner.prune(confirm: false)
      end

      it "skips confirmation prompt" do
        expect(output.string).not_to include("Proceed with deletion?")
      end

      it "completes prune" do
        expect(output.string).to include("Prune complete!")
      end
    end

    context "with branches containing special characters" do
      before do
        dev_dbs = "myapp_development_main\nmyapp_development_feature_with_slashes\n"
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /grep.*myapp_development_/)
          .and_return([dev_dbs, double])
        allow(Open3).to receive(:capture2)
          .with(anything, "bash", "-c", /grep.*myapp_test_/)
          .and_return(["", double])
        allow(BranchDb::Naming).to receive(:git_branches).and_return(%w[main feature/with-slashes])
      end

      it "matches sanitized branch names" do
        cleaner.prune
        expect(output.string).to include("No stale branch databases to prune")
      end
    end
  end
end
