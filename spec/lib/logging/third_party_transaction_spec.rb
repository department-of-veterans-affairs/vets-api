# frozen_string_literal: true

require 'rails_helper'
require 'logging/third_party_transaction'

RSpec.describe Logging::ThirdPartyTransaction do
  # to use the shared examples defined in this group for your test:
  # 1. define variable test_object of desired type using a `let` block
  # 2. test_object must define an instance method `method_to_wrap`
  # 3. test_object should extend Logging::ThirdPartyTransaction::MethodWrapper
  # 4. test_object definition should end with a call to .new, ensuring an object
  #    is returned to your variable, rather than the class definition block,
  #    as our linter will reject this.
  shared_examples_for 'a third party transaction logger' do
    context 'happy path' do
      it 'wraps a method in logging actions' do
        expect(test_object).to receive(:log_3pi_begin).at_least(:once)
        expect(test_object).to receive(:log_3pi_complete).at_least(:once)

        test_object.method_to_wrap
      end

      it 'returns the original methods return value' do
        expect(test_object.method_to_wrap).to eq 'return value'
      end
    end

    context 'when something goes wrong' do
      it 'fails quietly and logs the problem' do
        # Time is used in the logging methods
        allow(Time).to receive(:current).and_raise(StandardError)
        expect(Rails.logger).to receive(:error).and_call_original.at_least(:twice)

        test_object.method_to_wrap
      end
    end
  end

  describe 'controller usage' do
    let!(:test_object) do
      class TestController < ApplicationController
        extend Logging::ThirdPartyTransaction::MethodWrapper

        wrap_with_logging :method_to_wrap

        def method_to_wrap
          'return value'
        end

        self
      end.new
    end

    it_behaves_like 'a third party transaction logger'
  end

  describe 'worker usage' do
    let!(:test_object) do
      class TestWorker
        include Sidekiq::Worker
        extend Logging::ThirdPartyTransaction::MethodWrapper

        wrap_with_logging :method_to_wrap, additional_logs: { foo: 'bar' }

        def method_to_wrap
          'return value'
        end

        self
      end.new
    end

    it_behaves_like 'a third party transaction logger'
  end
end
