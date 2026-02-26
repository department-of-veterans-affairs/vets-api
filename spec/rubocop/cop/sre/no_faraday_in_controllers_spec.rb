# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/sre/no_faraday_in_controllers'

RSpec.describe RuboCop::Cop::Sre::NoFaradayInControllers, :config do
  subject(:cop) { described_class.new }

  def inspect_source_file(source, file_path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    commissioner.investigate(processed_source)
    cop.offenses
  end

  describe 'Faraday rescue in controllers' do
    it 'registers an offense for rescue Faraday::TimeoutError in a controller' do
      source = <<~RUBY
        begin
          call_service
        rescue Faraday::TimeoutError => e
          handle(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'app/controllers/my_controller.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 14]')
      expect(offenses.first.message).to include('Faraday::TimeoutError')
    end

    it 'registers an offense for rescue with multiple Faraday classes in a controller' do
      source = <<~RUBY
        begin
          call_service
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'app/controllers/api_controller.rb')
      expect(offenses.size).to eq(2)
    end

    it 'registers an offense for rescue ::Faraday::TimeoutError in a controller' do
      source = <<~RUBY
        begin
          call_service
        rescue ::Faraday::TimeoutError => e
          handle(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'app/controllers/my_controller.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 14]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for Faraday rescue outside controllers' do
      source = <<~RUBY
        begin
          call_service
        rescue Faraday::TimeoutError => e
          raise MyService::UpstreamTimeout, e.message
        end
      RUBY
      offenses = inspect_source_file(source, 'app/services/my_service.rb')
      expect(offenses).to be_empty
    end

    it 'does not register an offense for non-Faraday rescue in a controller' do
      source = <<~RUBY
        begin
          call_service
        rescue MyService::Error => e
          handle(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'app/controllers/my_controller.rb')
      expect(offenses).to be_empty
    end
  end
end
