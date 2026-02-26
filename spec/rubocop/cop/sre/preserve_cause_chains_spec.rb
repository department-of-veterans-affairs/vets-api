# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/preserve_cause_chains'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::PreserveCauseChains do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'broken cause chains' do
    it 'registers an offense for raise with string interpolating e.message in rescue' do
      offenses = inspect_source(<<~'RUBY')
        begin
          do_work
        rescue SomeError => e
          raise "Failed: #{e.message}"
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 02]')
      expect(offenses.first.message).to include('cause chain')
    end

    it 'registers an offense for raise with string interpolating the exception variable' do
      offenses = inspect_source(<<~'RUBY')
        begin
          do_work
        rescue SomeError => e
          raise "error: #{e}"
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 02]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for typed exception with two args' do
      expect_no_offenses(<<~'RUBY')
        begin
          do_work
        rescue SomeError => e
          raise MyError, "Failed: #{e.message}"
        end
      RUBY
    end

    it 'does not register an offense for bare re-raise' do
      expect_no_offenses(<<~RUBY)
        begin
          do_work
        rescue SomeError => e
          raise
        end
      RUBY
    end
  end
end
