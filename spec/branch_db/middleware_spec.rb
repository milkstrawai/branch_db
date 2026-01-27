RSpec.describe BranchDb::Middleware do
  let(:app) { double(call: [200, {}, ["OK"]]) }
  let(:env) { {} }
  let(:preparer) { instance_double(BranchDb::Preparer, prepare_if_needed: nil) }
  let(:db_config) { double(name: "primary") }

  before do
    stub_rails
    stub_active_record_base(configs_for: [db_config])
    allow(BranchDb::Preparer).to receive(:new).and_return(preparer)
  end

  def stub_branch(name)
    allow(BranchDb::Naming).to receive(:current_branch).and_return(name)
  end

  def stub_rails
    database_config = { "development" => { "primary" => { "database" => "test_db" } } }
    app_config = double(database_configuration: database_config)
    rails_app = double(config: app_config)
    stub_const("Rails", double(env: "development", logger: double(error: nil), application: rails_app))
  end

  def stub_active_record_base(configs_for: [])
    handler = double(clear_all_connections!: nil)
    new_configs = double(configs_for: configs_for)
    allow(ActiveRecord::DatabaseConfigurations).to receive(:new).and_return(new_configs)
    allow(ActiveRecord::Base).to receive_messages(
      configurations: double(configs_for: configs_for),
      connection_handler: handler,
      establish_connection: nil
    )
    allow(ActiveRecord::Base).to receive(:configurations=)
  end

  it "skips preparation when branch unchanged" do
    stub_branch("main")
    middleware = described_class.new(app)
    3.times { middleware.call(env) }
    expect(preparer).not_to have_received(:prepare_if_needed)
  end

  it "prepares when branch changes" do # rubocop:disable RSpec/ExampleLength
    stub_branch("main")
    middleware = described_class.new(app)
    stub_branch("feature")
    middleware.call(env)
    stub_branch("another")
    middleware.call(env)
    expect(preparer).to have_received(:prepare_if_needed).twice
  end

  it "handles detached HEAD gracefully" do
    stub_branch("")
    expect { described_class.new(app).call(env) }.not_to raise_error
  end

  it "handles database connection errors gracefully" do
    stub_branch("main")
    middleware = described_class.new(app)

    stub_branch("feature") # trigger branch change
    allow(BranchDb::Preparer).to receive(:new).and_raise(ActiveRecord::ConnectionNotEstablished)
    expect { middleware.call(env) }.not_to raise_error
  end

  it "returns the app response" do
    stub_branch("main")
    expect(described_class.new(app).call(env)).to eq([200, {}, ["OK"]])
  end
end
