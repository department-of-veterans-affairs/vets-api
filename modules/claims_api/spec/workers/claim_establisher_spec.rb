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
  end

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  let(:claim_no_ids) do
    claim = create(:auto_established_claim)
    bad_auth_headers = auth_headers
    bad_auth_headers['va_eauth_pid'] = ''
    bad_auth_headers['va_eauth_birlsfilenumber'] = ''
    claim.auth_headers = bad_auth_headers
    claim.save
    claim
  end

  let(:bad_claim) do
    claim = create(:auto_established_claim)
    bad_auth_headers = auth_headers
    bad_auth_headers['va_eauth_pid'] = ''
    bad_auth_headers['va_eauth_birlsfilenumber'] = ''
    bad_auth_headers['va_eauth_authorization'] = '{}'
    claim.auth_headers = bad_auth_headers
    claim.save
    claim
  end

  it 'submits successfully' do
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
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
  end

  it 'sets the status of the claim to an error if it raises an EVSS::DisabilityCompensationForm::Service error' do
    body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => 'Not established.' }] }
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(EVSS::DisabilityCompensationForm::ServiceException.new(body))
    )
    subject.new.perform(claim.id, failed: true)
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
    subject.new.perform(claim.id, failed: true)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
  end

  it 'fails current job if record fails to persist to the database' do
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::Service')
    allow(EVSS::DisabilityCompensationForm::Service).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }
    expect_any_instance_of(ClaimsApi::AutoEstablishedClaim).to receive(:save!)
      .and_raise(ActiveRecord::RecordInvalid.new(claim))

    expect do
      subject.new.perform(claim.id)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'retries fetching mpi if missing IDs (MPI success)' do
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::Service')
    allow(EVSS::DisabilityCompensationForm::Service).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

    subject.new.perform(claim_no_ids.id)
    claim_no_ids.reload
    expect(claim_no_ids.auth_headers['va_eauth_pid']).not_to eq('')
    expect(claim_no_ids.auth_headers['va_eauth_birlsfilenumber']).to eq('123412345')
  end

  it 'retries fetching mpi if missing IDs (failing MPI)' do
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::Service')
    allow(EVSS::DisabilityCompensationForm::Service).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

    expect do
      subject.new.perform(bad_claim.id)
    end.to raise_error(ClaimsApi::Error::MissingIdException)
    bad_claim.reload
    expect(bad_claim.auth_headers['va_eauth_pid']).to eq('')
    expect(bad_claim.auth_headers['va_eauth_birlsfilenumber']).to eq('')
  end

  it 'preserves original data upon BackendServiceException' do
    orig_data = claim.form_data
    body = [{ 'key' => 400, 'severity' => 'FATAL', 'text' => nil }]
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(Common::Exceptions::BackendServiceException.new)
    )
    subject.new.perform(claim.id, failed: true)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
    expect(claim.form_data).to eq(orig_data)
  end

  it 'preserves original data upon ServiceException' do
    orig_data = claim.form_data
    body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => nil }] }
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(::EVSS::DisabilityCompensationForm::ServiceException.new(body))
    )
    subject.new.perform(claim.id, failed: true)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body['messages'])
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
    expect(claim.form_data).to eq(orig_data)
  end

  it 'remains pending on first failures' do
    orig_data = claim.form_data
    body = [{ 'key' => 400, 'severity' => 'FATAL', 'text' => nil }]
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
      receive(:submit_form526).and_raise(Common::Exceptions::BackendServiceException.new)
    )
    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to be_nil
    expect(claim.evss_response).to eq(body)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::PENDING)
    expect(claim.form_data).to eq(orig_data)
  end

  it 'clears original data upon success' do
    evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::Service')
    allow(EVSS::DisabilityCompensationForm::Service).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

    subject.new.perform(claim.id)
    claim.reload
    expect(claim.evss_id).to eq(1337)
    expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
    expect(claim.form_data).to eq({})
  end
end
