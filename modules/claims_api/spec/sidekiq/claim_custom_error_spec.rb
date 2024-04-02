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
    context 'claim_establisher sends a backend exception' do
      error_original_body = { 
          messages: [
            {
              "key"=>"form526.submit.establishClaim.serviceError",
              "severity"=>"FATAL",
              "text"=>"Claim not established. System error with BGS. GUID: 00797c5d-89d4-4da6-aab7-24b4ad0e4a4f"
            }
          ]
        }

      let(:backend_error) { Common::Exceptions::BackendServiceException.new(
        backtrace.backtrace, 
        {}, 
        400, 
        error_original_body
      )}

      let(:backend_error_submit) { ClaimsApi::CustomError.new(backend_error, claim, 'submit') }

      it 'sets the evss_response to the original body errors' do
        backend_error_submit.build_error
      rescue => e
        expect(e.original_body[0]).to eq(error_original_body[:messages][0].deep_symbolize_keys)
      end
    end

    # context 'claim_establisher sends a Faraday ConnectionFailed' do
    #   let(:faraday_error) { Faraday::ConnectionFailed.new(backtrace) }
    #   let(:faraday_error_submit) { ClaimsApi::CustomError.new(faraday_error, claim, 'validate') }

    #   it 'handles the faraday error correctly' do
    #     faraday_error_submit.build_error
    #     faraday_error_submit.send(:build_error)
    #   rescue => e
    #     expect(e.errors[0]['detail']).to include 're-tryable'
    #   end
    # end

  #   context 'claim_establisher sends a Faraday::ServerError' do
  #     let(:faraday_error) { Faraday::ServerError.new(backtrace) }
  #     let(:faraday_error_submit) { ClaimsApi::CustomError.new(faraday_error, claim, 'validate') }

  #     it 'handles the faraday error correctly' do
  #       faraday_error_submit.build_error
  #       faraday_error_submit.send(:build_error)
  #     rescue => e
  #       expect(e.errors[0]['detail']).to include 're-tryable'
  #     end
  #   end
  # end

  # describe 'errors are funneled as re-tryable' do
  #   context 'claim_establisher sends a ActiveRecord::RecordInvalid' do
  #     let(:active_record_error) { ActiveRecord::RecordInvalid.new(claim) }
  #     let(:active_record_error_submit) { ClaimsApi::CustomError.new(active_record_error, claim, 'submit') }

  #     it 'handles it as a client exception' do
  #       active_record_error_submit.build_error
  #       active_record_error_submit.send(:build_error)
  #     rescue => e
  #       expect(e.errors[0]['detail']).to include 'client exception'
  #     end
  #   end

  #   context 'claim_establisher sends a Faraday::BadRequestError' do
  #     let(:bad_request_error) { Faraday::BadRequestError.new(claim) }
  #     let(:bad_request_error_submit) { ClaimsApi::CustomError.new(bad_request_error, claim, 'submit') }

  #     it 'handles it as a client exception' do
  #       bad_request_error_submit.build_error
  #       bad_request_error_submit.send(:build_error)
  #     rescue => e
  #       expect(e.errors[0]['detail']).to include 'client exception'
  #     end
  #   end

  #   context 'claim_establisher sends a Faraday::UnprocessableEntityError' do
  #     let(:unprocessable_error) { Faraday::UnprocessableEntityError.new(claim) }
  #     let(:unprocessable_error_submit) { ClaimsApi::CustomError.new(unprocessable_error, claim, 'submit') }

  #     it 'handles it as a client exception' do
  #       unprocessable_error_submit.build_error
  #       unprocessable_error_submit.send(:build_error)
  #     rescue => e
  #       expect(e.errors[0]['detail']).to include 'client exception'
  #     end
  #   end
  end
end
