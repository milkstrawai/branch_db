RSpec.describe BranchDb::Preparer do
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
  let(:db_config) { double(configuration_hash: config, name: "primary") }
  let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

  before do
    stub_branch_suffix
    allow(ActiveRecord::Base).to receive(:establish_connection)
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
  end

  def prepare = described_class.new(db_config, output:).prepare_if_needed

  describe "#prepare_if_needed" do
    context "when database is ready" do
      before { allow(connection).to receive(:table_exists?).with("schema_migrations").and_return(true) }

      it "reports ready" do
        prepare
        expect(output.string).to include("ready")
      end

      it "does not clone" do
        prepare
        expect(output.string).not_to include("Cloning")
      end

      it "establishes connection using db_config" do
        prepare
        expect(ActiveRecord::Base).to have_received(:establish_connection).with(db_config)
      end
    end

    context "when database needs cloning and source exists" do
      let(:cloner_instance) do
        instance_double(BranchDb::Cloner, clone: nil, target_db: config[:database],
                                          source_db: "myapp_development_main", source_exists?: true)
      end

      before do
        allow(connection).to receive(:table_exists?).with("schema_migrations").and_return(false)
        allow(BranchDb::Cloner).to receive(:new).and_return(cloner_instance)
      end

      it "triggers clone" do
        prepare
        expect(cloner_instance).to have_received(:clone)
      end
    end

    context "when database does not exist and source exists" do
      let(:cloner_instance) do
        instance_double(BranchDb::Cloner, clone: nil, target_db: config[:database],
                                          source_db: "myapp_development_main", source_exists?: true)
      end

      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::NoDatabaseError)
        allow(BranchDb::Cloner).to receive(:new).and_return(cloner_instance)
      end

      it "triggers clone" do
        prepare
        expect(cloner_instance).to have_received(:clone)
      end
    end

    context "when on main branch" do
      let(:db_config) { double(configuration_hash: { **config, database: "myapp_development_main" }, name: "primary") }
      let(:cloner_instance) do
        instance_double(BranchDb::Cloner, target_db: "myapp_development_main",
                                          source_db: "myapp_development_main")
      end

      before do
        stub_branch_suffix("_main")
        allow(connection).to receive(:table_exists?).with("schema_migrations").and_return(false)
        allow(BranchDb::Cloner).to receive(:new).and_return(cloner_instance)
      end

      it "defers to db:prepare" do
        prepare
        expect(output.string).to include("On main branch", "Deferring to db:prepare")
      end
    end

    context "when source database does not exist" do
      let(:cloner_instance) do
        instance_double(BranchDb::Cloner, target_db: config[:database],
                                          source_db: "myapp_development_main", source_exists?: false)
      end

      before do
        allow(connection).to receive(:table_exists?).with("schema_migrations").and_return(false)
        allow(BranchDb::Cloner).to receive(:new).and_return(cloner_instance)
      end

      it "defers to db:prepare" do
        prepare
        expect(output.string).to include("Source database not found", "Deferring to db:prepare")
      end
    end

    context "with secondary database" do
      let(:db_config) { double(configuration_hash: config, name: "cache") }

      before { allow(connection).to receive(:table_exists?).with("schema_migrations").and_return(true) }

      it "establishes connection to the specific database" do
        prepare
        expect(ActiveRecord::Base).to have_received(:establish_connection).with(db_config)
      end

      it "shows database name in output" do
        prepare
        expect(output.string).to include("(cache)")
      end
    end
  end
end
