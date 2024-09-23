# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

module Faker
  class Form < Base
    class << self
      def id
        prefix = Faker::Number.number(digits: 4)
        suffix = Faker::Alphanumeric.alpha(number: 2).upcase
        "#{prefix}#{suffix}"
      end
    end
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_run :focus
end
