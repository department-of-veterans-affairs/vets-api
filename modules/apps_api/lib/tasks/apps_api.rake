# frozen_string_literal: true

namespace :apps_api do
  desc 'Reload Okta Apps List'
  task reload_apps_list: :environment do
    puts 'Loading apps data from okta'
    AppsApi::DirectoryReloader.new.perform
    puts "Okta Applications have been reloaded and stored in cache"
  end
end
