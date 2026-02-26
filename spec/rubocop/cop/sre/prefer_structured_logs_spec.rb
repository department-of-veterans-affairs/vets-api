# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/prefer_structured_logs'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::PreferStructuredLogs do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'interpolated log messages' do
    it 'registers an offense for Rails.logger.error with interpolation' do
      offenses = inspect_source(<<~'RUBY')
        Rails.logger.error("User #{user_id} failed")
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 17]')
      expect(offenses.first.message).to include('structured logging')
    end

    it 'registers an offense for logger.warn with interpolation' do
      offenses = inspect_source(<<~'RUBY')
        logger.warn("Request to #{url}")
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 17]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for static string with structured data' do
      expect_no_offenses(<<~RUBY)
        Rails.logger.error("Request failed", user_id: user_id)
      RUBY
    end

    it 'does not register an offense for plain string without interpolation' do
      expect_no_offenses(<<~RUBY)
        Rails.logger.error("Static message")
      RUBY
    end

    it 'does not register an offense for non-logger calls with interpolation' do
      expect_no_offenses(<<~'RUBY')
        puts "Some #{interpolation}"
      RUBY
    end
  end
end
