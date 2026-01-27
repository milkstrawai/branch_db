module BranchDb
  class Railtie < Rails::Railtie
    railtie_name :branch_db

    rake_tasks do
      load File.expand_path("tasks/branch_db.rake", __dir__)
    end

    initializer "branch_db.middleware" do |app|
      app.middleware.use BranchDb::Middleware if Rails.env.development?
    end

    initializer "branch_db.test_prepare", after: :load_config_initializers do
      next unless Rails.env.test?

      db_configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
      db_configs.each do |db_config|
        ActiveRecord::Tasks::DatabaseTasks.create(db_config)
      rescue ActiveRecord::DatabaseAlreadyExists
        # already exists, nothing to do
      end
    end
  end
end
