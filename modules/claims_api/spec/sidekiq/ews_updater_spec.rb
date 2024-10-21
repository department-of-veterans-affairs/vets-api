# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EwsUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    ews.claim_id = '600065431'
    ews.save
  end

  let(:veteran_id) { '1012667145V762142' }
  let(:ews) { create(:evidence_waiver_submission, :with_full_headers_tamara) }

  context 'when waiver consent is present and allowed' do
    it 'updates evidence waiver record for a qualifying ews submittal' do
      VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_claim') do
        subject.new.perform(ews.id)
        ews.reload

        expect(ews.status).to eq(ClaimsApi::EvidenceWaiverSubmission::UPDATED)
      end
    end
  end

  describe 'when an errored job has a 48 hour time limitation' do
    it 'expires in 48 hours' do
      described_class.within_sidekiq_retries_exhausted_block do
        expect(subject).to be_expired_in 48.hours
      end
    end
  end

  context 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the EWS Updater Job'
      msg = { 'args' => [ews.id],
              'class' => described_class,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: ews.id,
          detail: "Job retries exhausted for #{described_class}",
          error: error_msg
        )
      end
    end
  end
end
