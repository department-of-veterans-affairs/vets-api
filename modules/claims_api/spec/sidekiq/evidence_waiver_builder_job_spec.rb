# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EvidenceWaiverBuilderJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }

  describe 'generating the filled and signed pdf' do
    it 'generates the pdf to match example' do
      allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
      expect(ClaimsApi::EvidenceWaiver).to receive(:new).and_call_original
      expect_any_instance_of(ClaimsApi::EvidenceWaiver).to receive(:construct).and_call_original

      subject.new.perform(ews.id)
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Evidence Waiver Builder Job'
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

  describe 'bad file number error raised by VBMS' do
    it 'EW builder job handles and sets status to errored, does not retry' do
      allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: 'asdf' })
      expect(ClaimsApi::EvidenceWaiver).to receive(:new).and_call_original
      expect_any_instance_of(ClaimsApi::EvidenceWaiver).to receive(:construct).and_call_original
      subject.new.perform(ews.id)
      ews.reload
      expect(ews.status).to eq('errored')
    end
  end
end
