# frozen_string_literal: true

module AppsApi
  class DirectoryReloader 
    include Sidekiq::Worker
    def perform
      Okta::DirectoryService.new.get_apps
    end
  end
end
