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

  let(:user) { FactoryBot.create(:user, :loa3) }

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
        expect(e.original_body[0][:key]).to be_a(String)
        expect(e.original_body[0][:key]).not_to be_an_instance_of(Integer)
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
        expect(e.original_body[0][:detail]).to include('Size must be between 8 and 9')
        expect(e.original_body[0][:key]).to include('header.va_eauth_birlsfilenumber.Invalid')
      end
    end
  end
end
