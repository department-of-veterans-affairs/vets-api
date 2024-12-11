# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::HttpErrorResponseBuilder do
  describe '.error_response' do
    context 'when error_type is :unauthorized' do
      it 'returns a forbidden status and appropriate error message' do
        result = described_class.error_response(:unauthorized)
        expected_result = {
          json: { errors: ['User is not authorized to perform the requested action'] },
          status: :forbidden
        }

        expect(result).to eq(expected_result)
      end
    end

    context 'when error_type is :not_found' do
      it 'returns a not_found status and appropriate error message' do
        result = described_class.error_response(:not_found)
        expected_result = {
          json: { errors: ['Resource not found'] },
          status: :not_found
        }

        expect(result).to eq(expected_result)
      end
    end

    context 'when error_type is unknown' do
      it 'returns nil' do
        result = described_class.error_response(:unknown_error_type)
        expect(result).to be_nil
      end
    end
  end
end
