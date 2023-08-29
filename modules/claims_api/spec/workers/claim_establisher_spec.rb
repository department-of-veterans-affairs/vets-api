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

  describe 'successful submission' do
    it 'submits successfully' do
      expect do
        subject.perform_async(claim.id)
      end.to change(subject.jobs, :size).by(1)
    end

    it 'sets a status of established on successful call' do
      evss_service_stub = instance_double('ClaimsApi::EVSSService::Base')
      allow(ClaimsApi::EVSSService::Base).to receive(:new) { evss_service_stub }
      allow(evss_service_stub).to receive(:submit) { OpenStruct.new(claimId: 1337) }

      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).not_to be_nil
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
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
    it 'sets the status of the claim to an error if it raises an EVSS::DisabilityCompensationForm::Service error' do
      body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => 'Not established.' }] }
      allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
        receive(:submit).and_raise(EVSS::DisabilityCompensationForm::ServiceException.new(body))
      )
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to be_nil
      expect(claim.evss_response).to eq(body['messages'])
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
    end

    it 'sets the status of the claim to an error if it raises an Common::Exceptions::BackendServiceException error' do
      body = [{ 'key' => 400, 'severity' => 'FATAL', 'text' => nil }]
      allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
        receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new)
      )
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to be_nil
      expect(claim.evss_response).to eq(body)
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
    end

    it 'fails current job if record fails to persist to the database' do
      evss_service_stub = instance_double('ClaimsApi::EVSSService::Base')
      allow(ClaimsApi::EVSSService::Base).to receive(:new) { evss_service_stub }
      allow(evss_service_stub).to receive(:submit) { OpenStruct.new(claim_id: 1337) }
      expect_any_instance_of(ClaimsApi::AutoEstablishedClaim).to receive(:save!)
        .and_raise(ActiveRecord::RecordInvalid.new(claim))

      expect do
        subject.new.perform(claim.id)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'preserves original data upon BackendServiceException' do
      orig_data = claim.form_data
      body = [{ 'key' => 400, 'severity' => 'FATAL', 'text' => nil }]
      allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
        receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new)
      )
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to be_nil
      expect(claim.evss_response).to eq(body)
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
      expect(claim.form_data).to eq(orig_data)
    end

    it 'preserves original data upon ServiceException' do
      orig_data = claim.form_data
      body = { 'messages' => [{ 'key' => 'serviceError', 'severity' => 'FATAL', 'text' => nil }] }
      allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
        receive(:submit).and_raise(::EVSS::DisabilityCompensationForm::ServiceException.new(body))
      )
      subject.new.perform(claim.id)
      claim.reload
      expect(claim.evss_id).to be_nil
      expect(claim.evss_response).to eq(body['messages'])
      expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
      expect(claim.form_data).to eq(orig_data)
    end
  end
end
