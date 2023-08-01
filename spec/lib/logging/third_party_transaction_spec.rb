# frozen_string_literal: true

require 'rails_helper'
require 'logging/third_party_transaction'

module TestObjectContent
  extend Logging::ThirdPartyTransaction::MethodWrapper

  wrap_with_logging(
    :method_to_wrap,
    additional_class_logs: { foo: 'bar' },
    additional_instance_logs: {
      i_work: %i[happy_instance_method],
      i_fail_silently: %i[happy_instance_method non_existent_method angry_instance_method]
    }
  )

  def method_to_wrap
    'return value'
  end

  def happy_instance_method
    'happy value'
  end

  def angry_instance_method
    raise 'hell'
  end
end

RSpec.describe Logging::ThirdPartyTransaction do
  let(:class_logs) { { foo: 'bar' } }
  let(:instance_logs) { { i_work: 'happy value', i_fail_silently: nil } }

  # to use the shared examples defined in this group for your test:
  # 1. define variable test_object of desired type using a `let` block
  # 2. test_object must define an instance method `method_to_wrap`
  # 3. test_object should extend Logging::ThirdPartyTransaction::MethodWrapper
  # 4. test_object definition should end with a call to .new, ensuring an object
  #    is returned to your variable, rather than the class definition block,
  #    as our linter will reject this.
  shared_examples_for 'a third party transaction logger' do
    context 'happy path' do
      it 'wraps a method in instnace and class level logging actions' do
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
        allow(Time).to receive(:current).and_raise(StandardError, 'your error, mlord')
        expect(Rails.logger).to receive(:error).and_call_original.at_least(:twice)

        test_object.method_to_wrap
      end
    end
  end

  describe 'controller usage' do
    let!(:test_object) do
      class TestController < ApplicationController
        include TestObjectContent

        self
      end.new
    end

    it_behaves_like 'a third party transaction logger'
  end

  describe 'worker usage' do
    let!(:test_object) do
      class TestWorker
        include TestObjectContent
        include Sidekiq::Worker

        self
      end.new
    end

    it_behaves_like 'a third party transaction logger'
  end

  describe 'PORO usage' do
    let!(:test_object) do
      class TestPoro
        include TestObjectContent

        self
      end.new
    end

    it_behaves_like 'a third party transaction logger'
  end
end
