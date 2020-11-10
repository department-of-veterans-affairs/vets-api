# frozen_string_literal: true

require 'sidekiq'
require 'rake'

module AppsApi
  class DirectoryLoader
    include Sidekiq::Worker
    include SentryLogging

    def perform
      application_name = Rails.application.class.module_parent_name
      application = Object.const_get(application_name)
      application::Application.load_tasks
      Rake::Task['apps_api:create_applications'].invoke
    end
  end
end
