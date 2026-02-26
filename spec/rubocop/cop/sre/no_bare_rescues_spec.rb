# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/sre/no_bare_rescues'

RSpec.describe RuboCop::Cop::Sre::NoBareRescues, :config do
  subject(:cop) { described_class.new }

  let(:config) { RuboCop::Config.new }

  describe 'bare rescues' do
    it 'registers an offense for rescue => e (no exception class)' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue => e
          handle(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 03]')
      expect(offenses.first.message).to include('Bare `rescue => e`')
    end

    it 'registers an offense for bare rescue (no variable, no class)' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue
          retry
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 03]')
      expect(offenses.first.message).to include('Bare `rescue => e`')
    end

    it 'registers an offense for rescue Exception => e' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue Exception => e
          handle(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 03]')
      expect(offenses.first.message).to include('rescue Exception')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for rescue StandardError => e' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue StandardError => e
          handle(e)
        end
      RUBY
    end

    it 'does not register an offense for rescue Faraday::TimeoutError => e' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue Faraday::TimeoutError => e
          handle(e)
        end
      RUBY
    end

    it 'does not register an offense for rescue with multiple specific classes' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle(e)
        end
      RUBY
    end
  end
end
