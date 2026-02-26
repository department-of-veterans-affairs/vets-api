# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/no_faraday_in_controllers'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::NoFaradayInControllers do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'Faraday rescue in controllers' do
    it 'registers an offense for rescue Faraday::TimeoutError in a controller' do
      offenses = inspect_source(<<~RUBY, 'app/controllers/my_controller.rb')
        begin
          call_service
        rescue Faraday::TimeoutError => e
          handle(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 14]')
      expect(offenses.first.message).to include('Faraday::TimeoutError')
    end

    it 'registers an offense for rescue with multiple Faraday classes in a controller' do
      offenses = inspect_source(<<~RUBY, 'app/controllers/api_controller.rb')
        begin
          call_service
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle(e)
        end
      RUBY
      expect(offenses.size).to eq(2)
    end

    it 'registers an offense for rescue ::Faraday::TimeoutError in a controller' do
      offenses = inspect_source(<<~RUBY, 'app/controllers/my_controller.rb')
        begin
          call_service
        rescue ::Faraday::TimeoutError => e
          handle(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 14]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for Faraday rescue outside controllers' do
      expect_no_offenses(<<~RUBY, 'app/services/my_service.rb')
        begin
          call_service
        rescue Faraday::TimeoutError => e
          raise MyService::UpstreamTimeout, e.message
        end
      RUBY
    end

    it 'does not register an offense for non-Faraday rescue in a controller' do
      expect_no_offenses(<<~RUBY, 'app/controllers/my_controller.rb')
        begin
          call_service
        rescue MyService::Error => e
          handle(e)
        end
      RUBY
    end
  end
end
