# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThirdPartyTransactionLogging do
  let!(:test_controller) do
    class TestController < ApplicationController
      extend ThirdPartyTransactionLogging::MethodWrapper

      wrap_with_logging :method_to_wrap

      def method_to_wrap
        'I dont actually do anything'
      end

      self
    end.new
  end

  context 'happy path' do
    it 'wraps a method in logging actions' do
      expect(test_controller).to receive(:log_3pi_begin).at_least(:once)
      expect(test_controller).to receive(:log_3pi_complete).at_least(:once)

      test_controller.method_to_wrap
    end
  end

  context 'when something goes wrong' do
    it 'fails quietly and logs the problem' do
      # Time is used in the logging methods
      allow(Time).to receive(:current).and_raise(StandardError)
      expect(Rails.logger).to receive(:error).and_call_original.at_least(:twice)

      test_controller.method_to_wrap
    end
  end
end
