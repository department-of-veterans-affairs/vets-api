# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

RSpec.describe ClaimsApi::ServiceBase do
  let(:user) { FactoryBot.create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp.to_json
  end

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  before do
    @service = described_class.new
  end

  describe '#set_established_state_on_claim' do
    it 'updates claim status as ESTABLISHED' do
      @service.send(:set_established_state_on_claim, claim)
      claim.reload
      expect(claim.status).to eq('established')
      expect(claim.evss_response).to eq(nil)
    end
  end

  describe '#set_pending_state_on_claim' do
    it 'updates claim status as PENDING' do
      @service.send(:set_pending_state_on_claim, claim)
      claim.reload
      expect(claim.status).to eq('pending')
    end
  end

  describe '#preserve_original_form_data' do
    it 'preserves the form data as expected' do
      preserved_form_data = @service.send(:preserve_original_form_data, claim.form_data)
      claim.reload
      expect(claim.form_data).to eq(preserved_form_data)
    end
  end

  describe '#set_errored_state_on_claim' do
    it 'updates claim status as ERRORED with error details' do
      @service.send(:set_errored_state_on_claim, claim)
      claim.reload
      expect(claim.status).to eq('errored')
    end
  end

  describe '#save_auto_claim!' do
    it 'saves claim with the validation_method property of v2' do
      @service.send(:save_auto_claim!, claim, claim.status)
      expect(claim.validation_method).to eq('v2')
    end
  end

  describe '#will_retry?' do
    it 'retries for a header.va_eauth_birlsfilenumber error' do
      body = [{ key: 'header.va_eauth_birlsfilenumber', severity: 'ERROR', text: 'Size must be between 8 and 9' }]

      error = Common::Exceptions::BackendServiceException.new(
        'header.va_eauth_birlsfilenumber', {}, nil, body
      )

      claim.evss_response = body
      claim.save!

      should_retry = @service.send(:will_retry?, claim, error)
      expect(should_retry).to eq(true)
    end

    it 'does not retry a form526.InProcess error' do
      body = [{ key: 'form526.InProcess', severity: 'FATAL', text: 'Form 526 is already in-process' }]

      error = Common::Exceptions::BackendServiceException.new(
        'form526.InProcess', {}, nil, body
      )

      claim.evss_response = body
      claim.save!

      should_retry = @service.send(:will_retry?, claim, error)
      expect(should_retry).to eq(false)
    end

    it 'does not retry a form526.submit.noRetryError error' do
      body = [{ key: 'form526.submit.noRetryError', severity: 'FATAL',
                text: 'Claim could not be established. Retries will fail.' }]

      error = Common::Exceptions::BackendServiceException.new(
        'form526.submit.noRetryError', {}, nil, body
      )

      claim.evss_response = body
      claim.save!

      should_retry = @service.send(:will_retry?, claim, error)
      expect(should_retry).to eq(false)
    end
  end

  describe '#log_job_progress' do
    let(:detail) { 'PDF mapper succeeded' }

    it 'logs job progress' do
      expect(ClaimsApi::Logger).to receive(:log).with('claims_api_sidekiq_service_base', claim_id: claim.id, detail:)

      @service.send(:log_job_progress, claim.id, detail)
    end
  end
end
