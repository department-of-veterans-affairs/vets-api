# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/concerns/logging_context'

RSpec.describe VAOS::LoggingContext do
  # Create a dummy class to test the concern
  let(:dummy_class) do
    Class.new do
      include VAOS::LoggingContext

      attr_accessor :user, :current_user

      def initialize(user: nil, current_user: nil)
        @user = user
        @current_user = current_user
      end
    end
  end

  let(:user) { double('User', va_treatment_facility_ids: %w[123 456 789]) }
  let(:instance) { dummy_class.new }

  describe '#controller_name' do
    it 'returns the controller name from RequestStore' do
      RequestStore.store['controller_name'] = 'TestController'
      expect(instance.controller_name).to eq('TestController')
    end

    it 'returns nil when controller name is not set' do
      RequestStore.store['controller_name'] = nil
      expect(instance.controller_name).to be_nil
    end
  end

  describe '#station_number' do
    context 'when user parameter is provided' do
      it 'returns the first treatment facility ID from the provided user' do
        expect(instance.station_number(user)).to eq('123')
      end

      it 'returns nil when user has no treatment facility IDs' do
        user_without_facilities = double('User', va_treatment_facility_ids: nil)
        expect(instance.station_number(user_without_facilities)).to be_nil
      end

      it 'returns nil when user has empty treatment facility IDs' do
        user_with_empty_facilities = double('User', va_treatment_facility_ids: [])
        expect(instance.station_number(user_with_empty_facilities)).to be_nil
      end
    end

    context 'when user parameter is not provided' do
      it 'falls back to @user instance variable' do
        instance.user = user
        expect(instance.station_number).to eq('123')
      end

      it 'falls back to @current_user instance variable when @user is nil' do
        instance.user = nil
        instance.current_user = user
        expect(instance.station_number).to eq('123')
      end

      it 'returns nil when no user is available' do
        instance.user = nil
        instance.current_user = nil
        expect(instance.station_number).to be_nil
      end
    end
  end

  describe '#eps_trace_id' do
    it 'returns the EPS trace ID from RequestStore' do
      RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      expect(instance.eps_trace_id).to eq('test-trace-id-123')
    end

    it 'returns nil when trace ID is not set' do
      RequestStore.store['eps_trace_id'] = nil
      expect(instance.eps_trace_id).to be_nil
    end
  end
end
