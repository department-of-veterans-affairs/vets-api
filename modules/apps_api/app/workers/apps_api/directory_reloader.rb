# frozen_string_literal: true

module AppsApi
  class DirectoryReloader 
    def perform
      puts "Hello There"
      AppsApi::DirectoryController.new.get_apps
    end
  end
end
