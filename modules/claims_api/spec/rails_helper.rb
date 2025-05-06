# frozen_string_literal: true

require 'spec_helper'
require 'support/factory_bot'
require_relative 'support/auth_helper'
require_relative 'support/stub_claims_api_auth_token'
require_relative 'support/bgs_client_spec_helpers'
require 'bd/bd'
require 'evss_service/base'

RSpec.configure do |config|
  config.before(:suite) do
    `truncate -s 0 log/test.log`
  end
  config.include FactoryBot::Syntax::Methods
  config.after(:suite) do
    @results ||= []
    keywords ||= File.readlines('modules/claims_api/spec/support/pii_key_words.txt', chomp: true).map!(&:downcase)
    File.readlines('log/test.log', chomp: true).each_with_index do |context, index|
      keywords.each do |phrase|
        @results << { line: index, phrase:, context: } if context.to_s.downcase.include?(phrase.downcase)
      end
    end

    if @results.present?
      puts ''
      puts '======================================='
      puts 'Start check for PII in test log'
      puts '======================================='
      puts @results.uniq!
      puts '======================================='
      puts 'End check for PII in test log'
      puts '======================================='
    end
  end
end
