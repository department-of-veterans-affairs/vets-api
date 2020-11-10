# frozen_string_literal: true

require 'sidekiq'
require 'rake'
require_relative '../../../lib/apps_api/directory_application_creator'

module AppsApi
  class DirectoryLoader
    include Sidekiq::Worker
    include SentryLogging

    def perform
      AppsApi::DirectoryApplicationCreator.new.call
    end
  end
end
