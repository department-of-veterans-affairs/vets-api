# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::EvidenceSubmissions::DeleteEvidenceSubmissionRecordsJob, type: :job do
  subject { described_class }

  describe 'perform' do
    let!(:es_lh_delete_one) { create(:bd_evidence_submission_for_deletion, job_class: 'BenefitsDocuments::Service') }
    let!(:es_evss_delete_two) { create(:bd_evidence_submission_for_deletion, job_class: 'EVSSClaimService') }
    let!(:es_no_delete) { create(:bd_evidence_submission_not_for_deletion) }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    context 'when EvidenceSubmission records have a delete_date set' do
      it 'deletes only the records with a past or current delete_time' do
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 2).exactly(1).time
        expect(Rails.logger)
          .to receive(:info)
          .with("#{subject} deleted 2 of 3 EvidenceSubmission records")
        subject.new.perform
        expect(EvidenceSubmission.where(id: es_no_delete.id).count).to eq(1)
        expect(EvidenceSubmission.where(id: es_lh_delete_one.id).count).to eq(0)
        expect(EvidenceSubmission.where(id: es_evss_delete_two.id).count).to eq(0)
      end
    end

    context 'when an exception is thrown' do
      let(:error_message) { 'Error message' }

      before do
        allow(EvidenceSubmission).to receive(:where).and_raise(ActiveRecord::ActiveRecordError.new(error_message))
      end

      it 'rescues and logs the exception' do
        expect(Rails.logger)
          .to receive(:error)
          .with("#{subject} error: ", error_message)
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.error').exactly(1).time
        expect { subject.new.perform }.not_to raise_error
      end
    end
  end
end
