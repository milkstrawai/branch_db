RSpec.describe BranchDb::PgUtils do
  let(:test_class) do
    Class.new do
      include BranchDb::PgUtils

      attr_reader :config

      def initialize(config)
        @config = config
      end
    end
  end

  let(:config) do
    {
      host: "localhost",
      port: 5432,
      username: "postgres",
      password: "secret"
    }
  end

  let(:instance) { test_class.new(config) }

  describe "#psql_flags" do
    it "builds correct psql connection flags" do
      expect(instance.send(:psql_flags)).to eq("-h localhost -p 5432 -U postgres")
    end

    it "escapes special characters in host" do
      config[:host] = "host with spaces"
      expect(instance.send(:psql_flags)).to include("host\\ with\\ spaces")
    end
  end

  describe "#pg_env" do
    it "returns hash with PGPASSWORD" do
      expect(instance.send(:pg_env)).to eq({ "PGPASSWORD" => "secret" })
    end

    it "handles nil password" do
      config[:password] = nil
      expect(instance.send(:pg_env)).to eq({ "PGPASSWORD" => "" })
    end
  end

  describe "#list_databases_cmd" do
    subject(:cmd) { instance.send(:list_databases_cmd) }

    it "includes psql command" do
      expect(cmd).to include("psql")
    end

    it "includes list flag" do
      expect(cmd).to include("-lqt")
    end

    it "includes sed for parsing" do
      expect(cmd).to include("sed")
    end
  end

  describe "#check_pg_tools!" do
    it "raises error when specified tool is not found" do
      allow(instance).to receive(:system).with("which missing_tool > /dev/null 2>&1").and_return(false)

      expect { instance.send(:check_pg_tools!, :missing_tool) }.to raise_error(
        BranchDb::Error, /missing_tool.*not found/
      )
    end

    it "does not raise when tool is available" do
      allow(instance).to receive(:system).with("which psql > /dev/null 2>&1").and_return(true)

      expect { instance.send(:check_pg_tools!, :psql) }.not_to raise_error
    end

    it "checks all specified tools" do
      allow(instance).to receive(:system).with("which psql > /dev/null 2>&1").and_return(true)
      allow(instance).to receive(:system).with("which pg_dump > /dev/null 2>&1").and_return(true)

      expect { instance.send(:check_pg_tools!, :psql, :pg_dump) }.not_to raise_error
    end

    it "checks all default tools when no arguments given" do
      BranchDb::PgUtils::PG_TOOLS.each do |tool|
        allow(instance).to receive(:system).with("which #{tool} > /dev/null 2>&1").and_return(true)
      end

      expect { instance.send(:check_pg_tools!) }.not_to raise_error
    end
  end
end
