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

  describe 'hash values with PII (rendered response body leak vector)' do
    it 'registers an offense for backend_response with .try(:original_body)' do
      offenses = inspect_source(<<~RUBY)
        { backend_response: error.try(:original_body) }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
      expect(offenses.first.message).to include('original_body')
    end

    it 'registers an offense for vamf_body with @env.body' do
      offenses = inspect_source(<<~RUBY)
        { vamf_body: @env.body }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
      expect(offenses.first.message).to include('body')
    end

    it 'registers an offense for backend_response with direct .original_body call' do
      offenses = inspect_source(<<~RUBY)
        { backend_response: error.original_body }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
    end

    it 'registers an offense for original_body key with .body value' do
      offenses = inspect_source(<<~RUBY)
        { original_body: response.body }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
    end

    it 'registers an offense for raw_body key with .try(:body)' do
      offenses = inspect_source(<<~RUBY)
        { raw_body: error.try(:body) }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
    end

    it 'registers an offense for response_body key with .try!(:original_body)' do
      offenses = inspect_source(<<~RUBY)
        { response_body: error.try!(:original_body) }
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 01]')
    end

    it 'registers an offense for original_error key with .original_error method' do
      offenses = inspect_source(<<~RUBY)
        { original_error: error.original_error }
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

    it 'does not register an offense for safe hash with error class and status' do
      expect_no_offenses(<<~RUBY)
        { error_class: error.class.name, code: error.original_status }
      RUBY
    end

    it 'does not register an offense for hash with non-suspicious keys even with .body' do
      expect_no_offenses(<<~RUBY)
        { content_type: response.content_type, status: response.status }
      RUBY
    end

    it 'does not register an offense for hash with safe identifiers' do
      expect_no_offenses(<<~RUBY)
        { user_uuid: current_user.uuid, appointment_id: appt.id }
      RUBY
    end

    it 'does not register an offense for meta hash with only safe fields' do
      expect_no_offenses(<<~RUBY)
        { meta: { error_class: e.class.name, status: 500 } }
      RUBY
    end
  end
end
