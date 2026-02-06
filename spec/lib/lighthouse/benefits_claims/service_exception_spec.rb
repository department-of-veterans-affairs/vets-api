# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service_exception'

RSpec.describe BenefitsClaims::ServiceException do
  describe '#initialize' do
    context 'when response is not a hash' do
      it 'raises the original response' do
        error = StandardError.new('some error')
        expect { described_class.new(error) }.to raise_error(StandardError, 'some error')
      end
    end

    context 'when response hash does not have a status key' do
      it 'raises TypeError when attempting to raise the response' do
        response = { body: { 'errors' => [] } }
        expect { described_class.new(response) }.to raise_error(TypeError)
      end
    end

    context 'when status is unmapped' do
      it 'raises ArgumentError' do
        response = { status: 418, body: {} }
        expect { described_class.new(response) }.to raise_error(ArgumentError, 'Unmapped status code: 418')
      end
    end

    context 'when response has standard Lighthouse errors array' do
      let(:response) do
        {
          status: 422,
          body: {
            'errors' => [
              {
                'title' => 'Unprocessable entity',
                'detail' => 'The property /serviceOrganization did not contain the required key poaCode',
                'code' => 'LIGHTHOUSE_422',
                'status' => '422',
                'source' => { 'pointer' => 'data/attributes/serviceOrganization' }
              }
            ]
          }
        }
      end

      it 'raises UnprocessableEntity with preserved error details' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
          first_error = error.errors.first
          expect(first_error[:title]).to eq('Unprocessable entity')
          expect(first_error[:detail]).to eq(
            'The property /serviceOrganization did not contain the required key poaCode'
          )
          expect(first_error[:code]).to eq('LIGHTHOUSE_422')
          expect(first_error[:source]).to eq({ 'pointer' => 'data/attributes/serviceOrganization' })
        end
      end
    end

    context 'when response has multiple errors' do
      let(:response) do
        {
          status: 422,
          body: {
            'errors' => [
              {
                'title' => 'Unprocessable entity',
                'detail' => 'Missing required field: poaCode',
                'status' => '422'
              },
              {
                'title' => 'Unprocessable entity',
                'detail' => 'Missing required field: registrationNumber',
                'status' => '422'
              }
            ]
          }
        }
      end

      it 'raises exception with all errors preserved' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
          expect(error.errors.length).to eq(2)
          expect(error.errors.first[:detail]).to eq('Missing required field: poaCode')
          expect(error.errors.second[:detail]).to eq('Missing required field: registrationNumber')
        end
      end
    end

    context 'when response has non-standard error format with message key' do
      let(:response) do
        {
          status: 400,
          body: {
            'message' => 'Invalid request parameters'
          }
        }
      end

      it 'extracts error from message field' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::BadRequest) do |error|
          expect(error.errors.first[:detail]).to eq('Invalid request parameters')
        end
      end
    end

    context 'when response has non-standard error format with error key' do
      let(:response) do
        {
          status: 400,
          body: {
            'error' => 'Something went wrong'
          }
        }
      end

      it 'extracts error from error field' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::BadRequest) do |error|
          expect(error.errors.first[:detail]).to eq('Something went wrong')
        end
      end
    end

    context 'when response body is not a hash' do
      let(:response) { { status: 500, body: 'Internal Server Error' } }

      it 'raises exception with nil errors' do
        expect { described_class.new(response) }.to raise_error(
          Common::Exceptions::ExternalServerInternalServerError
        )
      end
    end

    context 'when response body has empty errors array' do
      let(:response) do
        {
          status: 404,
          body: {
            'errors' => []
          }
        }
      end

      it 'falls back to body as single error' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::ResourceNotFound) do |error|
          expect(error.errors.first[:status]).to eq('404')
        end
      end
    end

    describe 'status code mapping' do
      [
        { status: 400, exception: Common::Exceptions::BadRequest },
        { status: 401, exception: Common::Exceptions::Unauthorized },
        { status: 403, exception: Common::Exceptions::Forbidden },
        { status: 404, exception: Common::Exceptions::ResourceNotFound },
        { status: 413, exception: Common::Exceptions::PayloadTooLarge },
        { status: 422, exception: Common::Exceptions::UnprocessableEntity },
        { status: 429, exception: Common::Exceptions::TooManyRequests },
        { status: 500, exception: Common::Exceptions::ExternalServerInternalServerError },
        { status: 502, exception: Common::Exceptions::BadGateway },
        { status: 503, exception: Common::Exceptions::ServiceUnavailable },
        { status: 504, exception: Common::Exceptions::GatewayTimeout }
      ].each do |test_case|
        it "maps status #{test_case[:status]} to #{test_case[:exception]}" do
          response = {
            status: test_case[:status],
            body: {
              'errors' => [{ 'title' => 'Test', 'detail' => 'Test error' }]
            }
          }
          expect { described_class.new(response) }.to raise_error(test_case[:exception])
        end
      end
    end

    context 'when status is provided as string' do
      let(:response) do
        {
          status: '422',
          body: {
            'errors' => [{ 'detail' => 'Validation failed' }]
          }
        }
      end

      it 'converts status to integer and maps correctly' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'with realistic Lighthouse API 422 response for missing claimantSsn' do
      let(:response) do
        {
          status: 422,
          body: {
            'errors' => [
              {
                'title' => 'Unprocessable entity',
                'detail' => 'Invalid claimantSsn parameter',
                'code' => 'LH422',
                'status' => '422'
              }
            ]
          }
        }
      end

      it 'preserves the specific validation error detail' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
          expect(error.errors.first[:detail]).to eq('Invalid claimantSsn parameter')
          expect(error.errors.first[:title]).to eq('Unprocessable entity')
        end
      end
    end

    context 'with realistic Lighthouse API 404 response for claim not found' do
      let(:response) do
        {
          status: 404,
          body: {
            'errors' => [
              {
                'title' => 'Resource not found',
                'detail' => 'Claim not found',
                'code' => 'LH404',
                'status' => '404'
              }
            ]
          }
        }
      end

      it 'preserves the specific not found error detail' do
        expect { described_class.new(response) }.to raise_error(Common::Exceptions::ResourceNotFound) do |error|
          expect(error.errors.first[:detail]).to eq('Claim not found')
          expect(error.errors.first[:title]).to eq('Resource not found')
        end
      end
    end
  end
end
