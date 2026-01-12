require 'rails_helper'
require 'rubocop'
require 'rubocop/rspec/support'

# Auto-require all custom cops
Dir[File.expand_path('../lib/rubocop/cop/**/*.rb', __dir__)].each { |f| require f }
