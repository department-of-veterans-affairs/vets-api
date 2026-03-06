# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/prefer_typed_exceptions'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::PreferTypedExceptions do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'string raises' do
    it 'registers an offense for raise with a string literal' do
      offenses = inspect_source(<<~RUBY)
        raise "something went wrong"
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 08]')
      expect(offenses.first.message).to include('RuntimeError')
    end

    it 'registers an offense for raise with an interpolated string' do
      offenses = inspect_source(<<~'RUBY')
        raise "failed: #{detail}"
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 08]')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for typed exception with message' do
      expect_no_offenses(<<~RUBY)
        raise MyApp::SomeError, "message"
      RUBY
    end

    it 'does not register an offense for typed exception without message' do
      expect_no_offenses(<<~RUBY)
        raise Common::Exceptions::BackendServiceException
      RUBY
    end

    it 'does not register an offense for bare re-raise' do
      expect_no_offenses(<<~RUBY)
        raise
      RUBY
    end
  end
end
