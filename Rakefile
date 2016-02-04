# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path("../config/application", __FILE__)

# Load rake support files
Dir[Rails.root.join("lib/tasks/support/**/*.rb")].each { |f| require f }

Rails.application.load_tasks
