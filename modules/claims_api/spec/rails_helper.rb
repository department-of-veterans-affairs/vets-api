# frozen_string_literal: true

require 'spec_helper'
require 'support/factory_bot'
require_relative 'support/auth_helper'
require_relative 'support/stub_claims_api_auth_token'
require 'bd/bd'
require 'evss_service/base'

RSpec.configure do |config|
  config.before(:suite) do
    `truncate -s 0 log/test.log`
  end
  config.after(:suite) do
    results = `fgrep -f modules/claims_api/spec/support/pii_key_words.txt log/test.log`
    if results.present?
      puts ''
      puts '======================================='
      puts 'Start check for PII in test log'
      puts '======================================='
      puts results
      puts '======================================='
      puts 'End check for PII in test log'
      puts '======================================='
    end
  end
end
