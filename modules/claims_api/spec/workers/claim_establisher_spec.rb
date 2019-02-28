# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::ClaimEstablisher, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  it 'submits succesfully' do
    VCR.use_cassette('evss/disability_compensation_form/submit_form') do
      expect do
        subject.perform_async(claim.id)
      end.to change(subject.jobs, :size).by(1)
      evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::ServiceAllClaim')
      expect(EVSS::DisabilityCompensationForm::ServiceAllClaim).to receive(:new) { evss_service_stub }
      expect(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to eq(1337)
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
    end
  end

  it 'sets the status of the claim to an error if it raises an error on EVSS' do
    service_stub = instance_double('EVSS::DisabilityCompensationForm::ServiceAllClaim')
    allow(EVSS::DisabilityCompensationForm::ServiceAllClaim).to receive(:new) { service_stub }
    expect do
      allow(service_stub).to receive(:submit_form526).and_raise(Common::Exceptions::BackendServiceException)
      subject.new.perform(claim.id)
    end.to raise_error(Common::Exceptions::BackendServiceException)
    claim.reload
    expect(claim.evss_id).to eq(nil)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
  end
end
