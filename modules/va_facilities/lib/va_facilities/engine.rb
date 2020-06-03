# frozen_string_literal: true

module VAFacilities
  class Engine < ::Rails::Engine
    isolate_namespace VAFacilities

    rake_tasks do
      Dir[File.join(root.to_s, '/lib/tasks/', '**/*.rake')].each do |file|
        load file
      end
    end

    initializer :append_migrations do |app|
      unless app.root.to_s.match? root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
          ActiveRecord::Migrator.migrations_paths << expanded_path
        end
      end
    end
  end
end
