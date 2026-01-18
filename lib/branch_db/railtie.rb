module BranchDb
  class Railtie < Rails::Railtie
    railtie_name :branch_db

    rake_tasks do
      load File.expand_path("tasks/branch_db.rake", __dir__)
    end
  end
end
