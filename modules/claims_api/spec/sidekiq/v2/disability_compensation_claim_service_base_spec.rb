# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'sidekiq/testing'

RSpec.describe ClaimsApi::V2::DisabilityCompensationClaimServiceBase do
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

  describe '#set_established_state_on_claim' do
    it 'updates claim status as ESTABLISHED' do
      service = described_class.new

      service.send(:set_established_state_on_claim, claim) # Invoke the protected method using send
      claim.reload
      expect(claim.status).to eq('established')
      expect(claim.evss_response).to eq(nil)
    end
  end

  describe '#set_pending_state_on_claim' do
    it 'updates claim status as PENDING' do
      service = described_class.new

      service.send(:set_pending_state_on_claim, claim)
      claim.reload
      expect(claim.status).to eq('pending')
    end
  end

  describe '#set_errored_state_on_claim' do
    it 'updates claim status as ERRORED with error details' do
      service = described_class.new

      service.send(:set_errored_state_on_claim, claim)
      claim.reload
      expect(claim.status).to eq('errored')
    end
  end

  describe '#save_auto_claim!' do
    it 'saves claim with the validation_method property of v2' do
      service = described_class.new

      service.send(:save_auto_claim!, claim, claim.status)
      expect(claim.validation_method).to eq('v2')
    end
  end

  describe '#log_job_progress' do
    let(:detail) { 'PDF mapper succeeded' }

    it 'logs job progress' do
      service = described_class.new
      expect(ClaimsApi::Logger).to receive(:log).with('526_v2_claim_service_base', claim_id: claim.id, detail:)

      service.send(:log_job_progress, claim.id, detail)
    end
  end

  RSpec.shared_examples 'logs to the Claim API logger correctly' do |service_class|
    it "for #{service_class}" do
      service = service_class
      claim_id = claim.id
      error_message = 'An error occurred'
      detail = "Job retries exhausted for #{service}"

      msg = { 'args' => [claim_id, 'value here'],
              'class' => service,
              'error_message' => error_message }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          claim_id:,
          detail:,
          error_message:
        )
      end
    end
  end

  describe "when a job's retries are exhausted" do
    include_examples 'logs to the Claim API logger correctly', ClaimsApi::V2::DisabilityCompensationPdfGenerator
    include_examples 'logs to the Claim API logger correctly',
                     ClaimsApi::V2::DisabilityCompensationDockerContainerUpload
    include_examples 'logs to the Claim API logger correctly',
                     ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader
  end
end
