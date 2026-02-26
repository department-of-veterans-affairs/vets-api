# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/sre/dont_swallow_errors'

RSpec.describe RuboCop::Cop::Sre::DontSwallowErrors, :config do
  subject(:cop) { described_class.new }

  let(:config) { RuboCop::Config.new }

  describe 'swallowed errors' do
    it 'registers an offense for rescue returning nil' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue => e
          nil
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 16]')
      expect(offenses.first.message).to include('nil')
    end

    it 'registers an offense for rescue returning false' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue => e
          false
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 16]')
      expect(offenses.first.message).to include('false')
    end

    it 'registers an offense for rescue returning empty array' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue => e
          []
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 16]')
      expect(offenses.first.message).to include('[]')
    end

    it 'registers an offense for rescue returning empty hash' do
      offenses = inspect_source(<<~RUBY)
        begin
          do_work
        rescue => e
          {}
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 16]')
      expect(offenses.first.message).to include('{}')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense when error is logged before returning nil' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue => e
          Rails.logger.error("failed", exception: e)
          nil
        end
      RUBY
    end

    it 'does not register an offense when error is re-raised' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue => e
          raise
        end
      RUBY
    end

    it 'does not register an offense for a non-empty array' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue => e
          [e.message]
        end
      RUBY
    end
  end
end
