module BranchDb
  class Railtie < Rails::Railtie
    railtie_name :branch_db

    rake_tasks do
      load File.expand_path("tasks/branch_db.rake", __dir__)
    end

    initializer "branch_db.middleware" do |app|
      app.middleware.use BranchDb::Middleware if Rails.env.development?
    end
  end
end
