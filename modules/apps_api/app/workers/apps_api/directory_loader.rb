# frozen_string_literal: true

require 'sidekiq'
require 'rake'

module AppsApi
  class DirectoryLoader
    include Sidekiq::Worker
    include SentryLogging

    def perform
      Rake::Task['apps_api:create_applications'].execute
    end
  end
end
