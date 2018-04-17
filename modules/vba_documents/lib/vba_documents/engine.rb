# frozen_string_literal: true

require 'aws-sdk-s3'

module VBADocuments
  class Engine < ::Rails::Engine
    isolate_namespace VBADocuments

    config.autoload_paths << File.expand_path("../lib/", __FILE__)
    # TODO eager_load_paths

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end
  end
end
