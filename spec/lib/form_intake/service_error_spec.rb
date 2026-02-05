# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/service_error'

RSpec.describe FormIntake::ServiceError do
  describe '#retryable?' do
    context 'error is not retryable' do
      it 'returns false' do
        service_error = described_class.new('Error message', 422)
        result = service_error.retryable?
        expect(result).to be(false)
      end
    end

    context 'error is retryable' do
      it 'returns true' do
        service_error = described_class.new('Error message', 500)
        result = service_error.retryable?
        expect(result).to be(true)
      end
    end

    context 'status code is not provided' do
      it 'defaults to retryable? = true' do
        service_error = described_class.new('No status provided')
        result = service_error.retryable?
        expect(result).to be(true)
      end
    end
  end
end
