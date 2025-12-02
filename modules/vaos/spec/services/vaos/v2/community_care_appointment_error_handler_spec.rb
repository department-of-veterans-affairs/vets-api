# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::CommunityCareAppointmentErrorHandler, type: :service do
  describe '.handle' do
    let(:context) { { operation: 'create_draft', referral_id: 'REF-123' } }

    context 'when handling business logic errors (Hash)' do
      context 'with authentication error' do
        let(:error) { { message: 'User authentication required', status: :unauthorized } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:unauthorized)
          expect(result[:response]).to eq({
                                            errors: [{
                                              title: 'Community Care appointment operation failed',
                                              detail: 'User authentication required',
                                              code: 'DRAFT_AUTHENTICATION_REQUIRED',
                                              meta: {
                                                operation: 'create_draft',
                                                reason: :unauthorized
                                              }
                                            }]
                                          })
        end
      end

      context 'with missing parameters error' do
        let(:error) { { message: 'Missing required parameters', status: :bad_request } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:bad_request)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_MISSING_PARAMETERS')
        end
      end

      context 'with referral invalid error' do
        let(:error) { { message: 'Required referral data is missing', status: :unprocessable_entity } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:unprocessable_entity)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_REFERRAL_INVALID')
        end
      end

      context 'with appointment check failed error' do
        let(:error) { { message: 'Error checking existing appointments', status: :bad_gateway } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:bad_gateway)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_APPOINTMENT_CHECK_FAILED')
        end
      end

      context 'with referral already used error' do
        let(:error) { { message: 'Referral is already used', status: :unprocessable_entity } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:unprocessable_entity)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_REFERRAL_ALREADY_USED')
        end
      end

      context 'with provider not found error' do
        let(:error) { { message: 'Provider not found', status: :not_found } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:not_found)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_PROVIDER_NOT_FOUND')
        end
      end

      context 'with draft creation failed error' do
        let(:error) { { message: 'Could not create draft appointment', status: :unprocessable_entity } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context:)

          expect(result[:status]).to eq(:unprocessable_entity)
          expect(result[:response][:errors][0][:code]).to eq('DRAFT_CREATION_FAILED')
        end
      end

      context 'with appointment conflict error' do
        let(:error) { { message: 'Appointment already exists', status: :conflict } }
        let(:submit_context) { { operation: 'submit', referral_number: 'REF-456' } }

        it 'returns standardized error response' do
          result = described_class.handle(error, context: submit_context)

          expect(result[:status]).to eq(:conflict)
          expect(result[:response][:errors][0][:code]).to eq('SUBMIT_APPOINTMENT_CONFLICT')
        end
      end

      context 'with unknown error message' do
        let(:error) { { message: 'Some unknown error', status: :unprocessable_entity } }

        it 'returns generic error code based on operation' do
          result = described_class.handle(error, context:)

          expect(result[:response][:errors][0][:code]).to eq('DRAFT_FAILED')
        end
      end

      context 'with submit operation and unknown error' do
        let(:error) { { message: 'Some unknown error', status: :unprocessable_entity } }
        let(:submit_context) { { operation: 'submit' } }

        it 'returns submit-specific error code' do
          result = described_class.handle(error, context: submit_context)

          expect(result[:response][:errors][0][:code]).to eq('SUBMIT_FAILED')
        end
      end
    end

    context 'when handling EPS service exceptions' do
      let(:eps_error) do
        instance_double(
          Eps::ServiceException,
          response_values: { detail: 'EPS service unavailable' },
          original_status: 503,
          original_body: { error: 'Service unavailable' }.to_json,
          key: 'EPS_ERROR',
          class: Eps::ServiceException
        )
      end

      it 'returns standardized error response with EPS error code' do
        result = described_class.handle(eps_error, context:)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:response]).to eq({
                                          errors: [{
                                            title: 'External service error',
                                            detail: 'EPS service unavailable',
                                            code: 'EPS_SERVICE_UNAVAILABLE',
                                            meta: {
                                              operation: 'create_draft',
                                              backend_service: 'EPS',
                                              original_status: 503,
                                              backend_detail: 'EPS service unavailable'
                                            }
                                          }]
                                        })
      end

      context 'with 400 status' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: { detail: 'Invalid request' },
            original_status: 400,
            original_body: { error: 'Bad request' }.to_json,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'maps to bad request status' do
          result = described_class.handle(eps_error, context:)

          expect(result[:status]).to eq(:bad_request)
          expect(result[:response][:errors][0][:code]).to eq('EPS_BAD_REQUEST')
        end
      end

      context 'with 404 status' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 404,
            original_body: { error: 'Not found' }.to_json,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'maps to not found status' do
          result = described_class.handle(eps_error, context:)

          expect(result[:status]).to eq(:not_found)
          expect(result[:response][:errors][0][:code]).to eq('EPS_NOT_FOUND')
        end
      end

      context 'with 409 status' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 409,
            original_body: { error: 'Conflict' }.to_json,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'maps to conflict status' do
          result = described_class.handle(eps_error, context:)

          expect(result[:status]).to eq(:conflict)
          expect(result[:response][:errors][0][:code]).to eq('EPS_CONFLICT')
        end
      end

      context 'when detail is in original_body errorMessage field' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 500,
            original_body: { errors: [{ errorMessage: 'Internal server error' }] }.to_json,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'extracts detail from errorMessage' do
          result = described_class.handle(eps_error, context:)

          expect(result[:response][:errors][0][:detail]).to eq('Internal server error')
        end
      end

      context 'when detail is in original_body message field' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 500,
            original_body: { message: 'Something went wrong' }.to_json,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'extracts detail from message' do
          result = described_class.handle(eps_error, context:)

          expect(result[:response][:errors][0][:detail]).to eq('Something went wrong')
        end
      end

      context 'when original_body is not parseable JSON' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 500,
            original_body: 'Not JSON',
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'returns generic error message' do
          result = described_class.handle(eps_error, context:)

          expect(result[:response][:errors][0][:detail]).to eq('Service error occurred')
        end
      end

      context 'when original_body is nil' do
        let(:eps_error) do
          instance_double(
            Eps::ServiceException,
            response_values: {},
            original_status: 500,
            original_body: nil,
            key: 'EPS_ERROR',
            class: Eps::ServiceException
          )
        end

        it 'returns generic error message' do
          result = described_class.handle(eps_error, context:)

          expect(result[:response][:errors][0][:detail]).to eq('Service error occurred')
        end
      end
    end

    context 'when handling VAOS backend service exceptions' do
      let(:vaos_error) do
        Common::Exceptions::BackendServiceException.new(
          'VAOS_502',
          { detail: 'VAOS service error' },
          502,
          { error: 'Gateway error' }.to_json
        )
      end

      it 'returns standardized error response with VAOS error code' do
        result = described_class.handle(vaos_error, context:)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:response][:errors][0][:code]).to eq('VAOS_SERVICE_UNAVAILABLE')
        expect(result[:response][:errors][0][:meta][:backend_service]).to eq('VAOS')
      end

      context 'with 404 status' do
        let(:vaos_error) do
          Common::Exceptions::BackendServiceException.new(
            'VAOS_404',
            {},
            404,
            { error: 'Not found' }.to_json
          )
        end

        it 'maps to VAOS not found code' do
          result = described_class.handle(vaos_error, context:)

          expect(result[:response][:errors][0][:code]).to eq('VAOS_NOT_FOUND')
        end
      end
    end

    context 'when handling CCRA backend service exceptions' do
      let(:ccra_error) do
        error = instance_double(
          Common::Exceptions::BackendServiceException,
          response_values: { detail: 'CCRA service error' },
          original_status: 500,
          original_body: { error: 'ccra internal error' }.to_json,
          key: 'CCRA_ERROR'
        )
        error
      end

      it 'returns standardized error response with CCRA error code' do
        result = described_class.handle(ccra_error, context:)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:response][:errors][0][:code]).to eq('CCRA_SERVICE_UNAVAILABLE')
        expect(result[:response][:errors][0][:meta][:backend_service]).to eq('CCRA')
      end

      context 'with 404 status' do
        let(:ccra_error) do
          instance_double(
            Common::Exceptions::BackendServiceException,
            response_values: {},
            original_status: 404,
            original_body: { error: 'ccra not found' }.to_json,
            key: 'CCRA_ERROR'
          )
        end

        it 'maps to CCRA referral not found code' do
          result = described_class.handle(ccra_error, context:)

          expect(result[:response][:errors][0][:code]).to eq('CCRA_REFERRAL_NOT_FOUND')
        end
      end
    end

    context 'when handling ActionController::ParameterMissing' do
      let(:param_error) { ActionController::ParameterMissing.new(:referral_number) }

      it 'returns standardized error response' do
        result = described_class.handle(param_error, context:)

        expect(result[:status]).to eq(:bad_request)
        expect(result[:response]).to eq({
                                          errors: [{
                                            title: 'Invalid request parameters',
                                            detail: 'Required parameter missing: referral_number',
                                            code: 'INVALID_REQUEST_PARAMETERS',
                                            meta: {
                                              operation: 'create_draft'
                                            }
                                          }]
                                        })
      end
    end

    context 'when handling Redis::BaseError' do
      let(:redis_error) { Redis::BaseError.new('Connection refused') }

      it 'returns standardized error response' do
        result = described_class.handle(redis_error, context:)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:response]).to eq({
                                          errors: [{
                                            title: 'Service temporarily unavailable',
                                            detail: 'Unable to connect to cache service. Please try again.',
                                            code: 'CACHE_SERVICE_UNAVAILABLE',
                                            meta: {
                                              operation: 'create_draft'
                                            }
                                          }]
                                        })
      end
    end

    context 'when handling ArgumentError' do
      let(:arg_error) { ArgumentError.new('Invalid argument provided') }

      it 'returns standardized error response' do
        result = described_class.handle(arg_error, context:)

        expect(result[:status]).to eq(:bad_request)
        expect(result[:response][:errors][0][:code]).to eq('INVALID_ARGUMENT')
        expect(result[:response][:errors][0][:detail]).to eq('ArgumentError')
      end
    end

    context 'when handling unexpected errors' do
      let(:unexpected_error) { StandardError.new('Something went wrong') }

      it 'returns generic error response' do
        result = described_class.handle(unexpected_error, context:)

        expect(result[:status]).to eq(:internal_server_error)
        expect(result[:response]).to eq({
                                          errors: [{
                                            title: 'Unexpected error occurred',
                                            detail: 'An unexpected error occurred. Please try again.',
                                            code: 'UNEXPECTED_ERROR',
                                            meta: {
                                              operation: 'create_draft'
                                            }
                                          }]
                                        })
      end
    end

    context 'when context is empty' do
      let(:error) { { message: 'Provider not found', status: :not_found } }
      let(:empty_context) { {} }

      it 'returns response without meta when no metadata is present' do
        result = described_class.handle(error, context: empty_context)

        # Meta will contain reason from the error hash
        expect(result[:response][:errors][0][:meta]).to eq({ reason: :not_found })
      end
    end

    context 'when handling backend service exception with unknown service' do
      let(:unknown_error) do
        instance_double(
          Common::Exceptions::BackendServiceException,
          response_values: {},
          original_status: 500,
          original_body: { error: 'Unknown service error' }.to_json,
          key: 'UNKNOWN_SERVICE_ERROR'
        )
      end

      it 'returns generic backend service error code' do
        result = described_class.handle(unknown_error, context:)

        expect(result[:response][:errors][0][:code]).to eq('BACKEND_SERVICE_ERROR')
        expect(result[:response][:errors][0][:meta][:backend_service]).to eq('Unknown')
      end
    end

    context 'when handling backend service exception with 4xx status' do
      let(:client_error) do
        instance_double(
          Common::Exceptions::BackendServiceException,
          response_values: {},
          original_status: 422,
          original_body: { error: 'Unprocessable entity' }.to_json,
          key: 'CLIENT_ERROR'
        )
      end

      it 'maps to unprocessable entity status' do
        result = described_class.handle(client_error, context:)

        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context 'when handling backend service exception with no original_status' do
      let(:no_status_error) do
        instance_double(
          Common::Exceptions::BackendServiceException,
          response_values: {},
          original_status: nil,
          original_body: { error: 'Error without status' }.to_json,
          key: 'NO_STATUS_ERROR'
        )
      end

      it 'defaults to bad gateway status' do
        result = described_class.handle(no_status_error, context:)

        expect(result[:status]).to eq(:bad_gateway)
      end
    end
  end
end
