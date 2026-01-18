module SpecHelpers
  def stub_rake_task(name)
    task = instance_double(Rake::Task, invoke: true, reenable: true, prerequisite_tasks: [])
    allow(Rake::Task).to receive(:[]).with(name).and_return(task)
    task
  end

  def stub_pg_tools_available(instance)
    allow(instance).to receive(:system).with("which psql > /dev/null 2>&1").and_return(true)
    allow(instance).to receive(:system).with("which pg_dump > /dev/null 2>&1").and_return(true)
    allow(instance).to receive(:system).with("which dropdb > /dev/null 2>&1").and_return(true)
  end

  def stub_branch_suffix(suffix = "_feature_auth")
    allow(BranchDb::Naming).to receive(:branch_suffix).and_return(suffix)
  end

  def stub_parent_branch(parent = "main")
    allow(BranchDb::Naming).to receive(:parent_branch).and_return(parent)
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
