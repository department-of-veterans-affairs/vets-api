# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/dont_leak_pii'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::DontLeakPii do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'raise with PII' do
    it 'registers an offense when interpolating .body into raise' do
      offenses = inspect_source(<<~'RUBY')
        raise "Failed: #{response.body}"
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
      expect(offenses.first.message).to include('.body')
    end

    it 'registers an offense when interpolating params into raise' do
      offenses = inspect_source(<<~'RUBY')
        raise "Bad: #{params}"
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
      expect(offenses.first.message).to include('.params')
    end
  end

  describe 'logger with PII' do
    it 'registers an offense when interpolating .body into Rails.logger' do
      offenses = inspect_source(<<~'RUBY')
        Rails.logger.error("Bad: #{resp.body}")
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
      expect(offenses.first.message).to include('log message')
    end

    it 'registers an offense when interpolating params into logger.warn' do
      offenses = inspect_source(<<~'RUBY')
        logger.warn("Data: #{params}")
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for typed exception without interpolation' do
      expect_no_offenses(<<~RUBY)
        raise Common::Exceptions::BackendServiceException
      RUBY
    end

    it 'does not register an offense for structured logging without .body/.params' do
      expect_no_offenses(<<~RUBY)
        Rails.logger.error("Failed", status: response.status)
      RUBY
    end

    it 'does not register an offense for raise with interpolation that is not .body/.params' do
      expect_no_offenses(<<~'RUBY')
        raise "Failed: #{status_code}"
      RUBY
    end
  end
end
