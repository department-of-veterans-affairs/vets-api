# frozen_string_literal: true

module AppsApi
  class DirectoryReloader 
    def perform
      Okta::DirectoryService.new.get_apps
    end
  end
end
