# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ClaimEstablisher, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user)
                                           .add_headers(EVSS::AuthHeaders.new(user).to_h)
                                           .merge(BGS::AuthHeaders.new(user).to_h)
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
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::Service')
    allow(EVSS::DisabilityCompensationForm::Service).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to eq(1337)
    expect(claim.form_data).to be_empty
    expect(claim.auth_headers).to be_empty
    expect(claim.file_data).to be_nil
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
  end

  it 'sets the status of the claim to an error if it raises an EVSS::DisabilityCompensationForm::Service error' do
    body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => 'Not established.' }] }
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(EVSS::DisabilityCompensationForm::ServiceException.new(body))
    )
    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body['messages'])
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
  end

  it 'sets the status of the claim to an error if it raises an Common::Exceptions::BackendServiceException error' do
    body = [{ 'key' => 400, 'severity' => 'FATAL', 'text' => nil }]
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(Common::Exceptions::BackendServiceException.new)
    )
    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
  end
end
