# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::ClaimEstablisher, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

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
    expect do
      subject.perform_async(claim.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'sets a status of established on successful call' do
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::ServiceAllClaim')
    allow(EVSS::DisabilityCompensationForm::ServiceAllClaim).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to eq(1337)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
  end

  it 'sets the status of the claim to an error if it raises an error on EVSS' do
    body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => 'Not established.' }] }
    allow_any_instance_of(EVSS::DisabilityCompensationForm::ServiceAllClaim).to(
      receive(:submit_form526).and_raise(EVSS::DisabilityCompensationForm::ServiceException.new(body))
    )
    expect { subject.new.perform(claim.id) }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)

    claim.reload
    expect(claim.evss_id).to eq(nil)
    expect(claim.evss_response).to eq(original_body['messages'])
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
  end
end
