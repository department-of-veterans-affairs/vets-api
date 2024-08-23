# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

RSpec.describe ClaimsApi::ClaimEstablisher, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_status_v1_lh_auto_establish_claim_enabled).and_return true
    stub_claims_api_auth_token
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user)
                                           .add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe 'successful submission' do
    it 'submits successfully' do
      expect do
        subject.perform_async(claim.id)
      end.to change(subject.jobs, :size).by(1)
    end

    it 'sets a status of established on successful call' do
      VCR.use_cassette('claims_api/evss/submit') do
        subject.new.perform(claim.id)
        claim.reload
        expect(claim.evss_id).not_to be_nil
        expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      end
    end

    it 'clears original data upon success' do
      evss_service_stub = instance_double('ClaimsApi::EVSSService::Base')
      allow(ClaimsApi::EVSSService::Base).to receive(:new) { evss_service_stub }
      allow(evss_service_stub).to receive(:submit) { OpenStruct.new(claimId: 1337) }

      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to eq(1337)
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      expect(claim.form_data).to eq({})
    end
  end

  describe 'errored submission' do
    let(:errors) do
      [{ 'title' => 'Operation failed', 'detail' => 'Operation failed', 'code' => 'VA900', 'status' => '400' }]
    end

    it 'sets the status of the claim to an error if it raises an Common::Exceptions::BackendServiceException error' do
      evss_service_stub = instance_double('ClaimsApi::EVSSService::Base')
      allow(ClaimsApi::EVSSService::Base).to receive(:new) { evss_service_stub }
      allow(evss_service_stub).to receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                                               errors
                                                             ))
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to be_nil
      expect(claim.evss_response).to eq(errors)
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Claim Establisher Job'
      msg = { 'args' => [claim.id],
              'class' => described_class,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: claim.id,
          detail: "Job retries exhausted for #{described_class}",
          error: error_msg
        )
      end
    end
  end
end
