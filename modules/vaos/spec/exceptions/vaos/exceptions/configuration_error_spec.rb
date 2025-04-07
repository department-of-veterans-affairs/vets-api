# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/exceptions/vaos/exceptions/configuration_error'

describe VAOS::Exceptions::ConfigurationError do
  let(:original_error) { StandardError.new('Test error message') }
  let(:service_name) { 'TestService' }
  let(:exception) { described_class.new(original_error, service_name) }

  describe '#initialize' do
    it 'stores the original error' do
      expect(exception.error).to eq(original_error)
    end
  end

  describe '#status' do
    it 'returns 503 (Service Unavailable)' do
      expect(exception.status).to eq(503)
    end
  end

  describe '#code' do
    it 'returns the error code' do
      expect(exception.code).to eq('VAOS_CONFIG_ERROR')
    end
  end

  describe '#i18n_data' do
    it 'returns the custom error data' do
      expect(exception.i18n_data).to include(
        title: 'Service Configuration Error',
        code: 'VAOS_CONFIG_ERROR',
        status: '503'
      )
    end
  end

  describe '#errors' do
    let(:error_object) { exception.errors.first }

    it 'returns an array with a single error object' do
      expect(exception.errors).to be_an(Array)
      expect(exception.errors.size).to eq(1)
    end

    it 'formats the error with the correct title' do
      expect(error_object.title).to eq('Service Configuration Error')
    end

    it 'includes the service name in the detail message' do
      expect(error_object.detail).to eq("The #{service_name} service is unavailable due to a configuration issue")
    end

    it 'uses the standard error code' do
      expect(error_object.code).to eq('VAOS_CONFIG_ERROR')
    end

    it 'includes the status code as a string' do
      expect(error_object.status).to eq('503')
    end

    it 'includes the source' do
      expect(error_object.source).to eq(service_name)
    end
  end
end
