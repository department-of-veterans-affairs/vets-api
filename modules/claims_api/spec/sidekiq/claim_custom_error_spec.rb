# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

RSpec.describe ClaimsApi::CustomError, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_status_v1_lh_auto_establish_claim_enabled).and_return true
    stub_claims_api_auth_token
  end

  let(:user) { create(:user, :loa3) }

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.save
    claim
  end

  let(:backtrace) do
    OpenStruct.new(backtrace: [
                     "/vets-api/lib/common/client/middleware/response/raise_error.rb:30:in `raise_error!'",
                     "/vets-api/lib/common/client/middleware/response/raise_error.rb:23:in `on_complete'"
                   ])
  end

  describe 'errors are funneled as service errors and set to raise and not re-try' do
    context 'no longer wraps the error and sets the key as an integer' do
      error_original_body = {
        messages: [
          {
            'key' => 'form526.submit.establishClaim.serviceError',
            'severity' => 'FATAL',
            'text' => 'Claim not established. System error with BGS. GUID: 00797c5d-89d4-4da6-aab7-24b4ad0e4a4f'
          }
        ]
      }

      let(:backend_error) do
        Common::Exceptions::BackendServiceException.new(
          backtrace.backtrace,
          {},
          400,
          error_original_body
        )
      end

      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error) }

      it 'correctly sets the key as the string value from the error message' do
        backend_error_submit.build_error
      rescue => e
        expect(e.errors[0][:title]).to eq('Backend Service Exception')
        expect(e.errors[0][:detail]).to eq('Claim not established. System error with BGS. ' \
                                           'GUID: 00797c5d-89d4-4da6-aab7-24b4ad0e4a4f')
      end
    end

    context 'the BIRLS file number is the wrong size' do
      error_original_body = {
        messages: [
          {
            'key' => 'header.va_eauth_birlsfilenumber.Invalid',
            'severity' => 'ERROR',
            'text' => 'Size must be between 8 and 9'
          }
        ]
      }

      let(:backend_error) do
        Common::Exceptions::BackendServiceException.new(
          backtrace.backtrace,
          { status: 400, detail: nil, code: 'VA900', source: nil },
          400,
          error_original_body
        )
      end

      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error) }

      it 'sets the evss_response to the original body error message' do
        backend_error_submit.build_error
      rescue => e
        expect(e.errors[0][:detail]).to eq('Size must be between 8 and 9')
        expect(e.errors[0][:title]).to eq('Backend Service Exception')
      end
    end

    context 'the error is returned as a string from the EVSS docker container' do
      error_original_body = 'ClamsApi::claim failed '

      let(:backend_error) do
        Common::Exceptions::BackendServiceException.new(
          backtrace.backtrace,
          { status: 400, detail: nil, code: 'VA900', source: nil },
          400,
          error_original_body
        )
      end

      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error) }

      it 'handles a string error message' do
        backend_error_submit.build_error
      rescue => e
        expect(e.errors[0][:title]).to eq('String error')
        expect(e.errors[0][:status]).to eq('422')
        expect(e.errors[0][:detail]).to eq(error_original_body)
      end
    end

    context 'the error.original_body is returned as a string from the EVSS docker container' do
      let(:string_error) { 'ClamsApi::claim failed ' }

      let(:string_error_submit) { ClaimsApi::CustomError.new(string_error) }

      it 'handles a string error message' do
        string_error_submit.build_error
      rescue => e
        expect(e.errors[0][:title]).to eq('String error')
        expect(e.errors[0][:status]).to eq('422')
        expect(e.errors[0][:detail]).to eq(string_error)
      end
    end

    context 'when warning messages are returned' do
      error_original_body = {
        messages: [
          {
            'key' => 'form526.disabilities[1].isDuplicate',
            'severity' => 'WARN',
            'text' => 'Claimant has added a duplicate disability'
          },
          {
            'key' => 'form526.disabilities[2].disabilityActionTypeNONE.ratedDisability.isInvalid',
            'severity' => 'ERROR',
            'text' => 'An attempt was made to add a secondary disability to an existing rated Disability. The rated ' \
                      'Disability could not be found'
          }
        ]
      }

      let(:backend_error) do
        Common::Exceptions::BackendServiceException.new(
          backtrace.backtrace,
          {},
          400,
          error_original_body
        )
      end

      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error) }

      it 'excludes warnings but includes errors in the response' do
        backend_error_submit.build_error
      rescue => e
        expect(e.errors.length).to eq(1)
        expect(e.errors[0][:title]).to eq('Backend Service Exception')
        expect(e.errors[0][:detail]).to eq('An attempt was made to add a secondary disability to an existing rated ' \
                                           'Disability. The rated Disability could not be found')
      end
    end
  end

  context 'an external service returns a 504' do
    error_original_body = {
      messages: [
        {
          'key' => 'timeout',
          'severity' => 'ERROR',
          'text' => 'external service timeout'
        }
      ]
    }

    let(:external_timeout) do
      Common::Exceptions::BackendServiceException.new(
        backtrace.backtrace,
        { status: 504, detail: 'timeout' },
        504,
        error_original_body
      )
    end

    let(:external_timeout_submit) { ClaimsApi::CustomError.new(external_timeout) }

    it 'raises a 502' do
      external_timeout_submit.build_error
    rescue => e
      expect(e.errors[0][:status]).to eq('502')
      expect(e.errors[0][:title]).to eq('Bad gateway')
      expect(e.errors[0][:detail]).to eq('The server received an invalid or null response from an upstream server.')
    end
  end

  describe 'for the get_error_info method' do
    context 'when the original_body hash does not contain a messages key' do
      error_original_body = { status: 'error', code: 'SOME_ERROR_CODE' }
      let(:backend_error) { Common::Exceptions::BackendServiceException.new({}, 400, error_original_body) }
      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error) }

      it 'does not raise a KeyError when accessing missing messages key' do
        # Test that get_error_info method doesn't throw KeyError
        expect { backend_error_submit.send(:get_error_info) }.not_to raise_error
        # Verify it returns an empty array when no messages exist
        result = backend_error_submit.send(:get_error_info)
        expect(result).to eq([])
      end

      it 'still raises the intended BackendServiceException from build_error' do
        expected_exception = ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException
        expect { backend_error_submit.build_error }.to raise_error(expected_exception) do |error|
          expect(error.errors).to eq([])
        end
      end
    end
  end

  describe 'FES errors' do
    let(:response_values) do
      { status: 400, detail: nil, code: 'VA_400', source: nil }
    end
    let(:bad_request_detail) do
      { errors: [
        {
          detail: 'Http Message Not Readable (Unrecognized Property)', status: 400, title: 'Bad Request',
          instance: 'b3a8fe91', diagnostics: '285vwsmYlv='
        }
      ] }
    end
    let(:invalid_data_detail) do
      { data: {
        valid: false,
        errors: [
          { status: '400', title: 'Invalid service period branch name',
            detail: 'Provided service period branch name is not valid: AIR\\n Force',
            source: {
              pointer: '/data/form526/serviceInformation/servicePeriods/0/serviceBranch'
            } }
        ]
      } }
    end

    # (key = nil, response_values = {}, original_status = nil, original_body = nil)
    let(:bad_request) do
      Common::Exceptions::BackendServiceException.new('VA_400', response_values, 400, bad_request_detail)
    end

    let(:invalid_data) do
      Common::Exceptions::BackendServiceException.new('VA_400', response_values, 400, invalid_data_detail)
    end

    it 'handles returning a message when :errors is inside the original_body not :messages' do
      ClaimsApi::CustomError.new(bad_request, bad_request_detail, false).build_error
    rescue => e
      expect(e.errors[0][:status]).to eq('422') # standards require this to be a string
      expect(e.errors[0][:title]).to eq('Backend Service Exception')
      expect(e.errors[0][:detail]).to eq('The claim could not be established - Http Message Not Readable ' \
                                         '(Unrecognized Property).')
    end

    it 'handles returning a message when :errors is inside :data in the original_body not :messages' do
      ClaimsApi::CustomError.new(invalid_data, invalid_data_detail, false).build_error
    rescue => e
      expect(e.errors[0][:status]).to eq('422') # standards require this to be a string
      expect(e.errors[0][:title]).to eq('Backend Service Exception')
      expect(e.errors[0][:detail]).to eq('The claim could not be established - Provided service period branch ' \
                                         'name is not valid: AIR\\n Force.')
    end
  end
end
