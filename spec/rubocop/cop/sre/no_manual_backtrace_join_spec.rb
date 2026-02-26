# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/no_manual_backtrace_join'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::NoManualBacktraceJoin do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'backtrace.join calls' do
    it 'registers an offense for e.backtrace.join("\n")' do
      offenses = inspect_source(<<~RUBY)
        e.backtrace.join("\\n")
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 20]')
    end

    it 'registers an offense for error.backtrace.join(", ")' do
      offenses = inspect_source(<<~RUBY)
        error.backtrace.join(', ')
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 20]')
    end

    it 'registers an offense for e.backtrace.join with no argument' do
      offenses = inspect_source(<<~RUBY)
        e.backtrace.join
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 20]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for e.backtrace without join' do
      expect_no_offenses(<<~RUBY)
        e.backtrace
      RUBY
    end

    it 'does not register an offense for join on a non-backtrace array' do
      expect_no_offenses(<<~'RUBY')
        some_array.join("\n")
      RUBY
    end
  end
end
