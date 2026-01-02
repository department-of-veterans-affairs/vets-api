# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::EvidenceSubmissions::DeleteEvidenceSubmissionRecordsJob, type: :job do
  subject { described_class }

  describe 'perform' do
    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    context 'when deleting SUCCESS records' do
      let!(:es_success_delete_one) do
        create(:bd_evidence_submission_for_deletion, job_class: 'BenefitsDocuments::Service')
      end
      let!(:es_success_delete_two) do
        create(:bd_evidence_submission_for_deletion, job_class: 'EVSSClaimService')
      end

      it 'deletes SUCCESS records with a past or current delete_date and reports metrics with status tag' do
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 2, tags: ['status:success'])
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 0, tags: ['status:failed'])
        expect(Rails.logger)
          .to receive(:info)
          .with("#{subject} deleted 2 of 2 EvidenceSubmission records (2 success, 0 failed)")

        subject.new.perform

        expect(EvidenceSubmission.where(id: es_success_delete_one.id).count).to eq(0)
        expect(EvidenceSubmission.where(id: es_success_delete_two.id).count).to eq(0)
      end
    end

    context 'when deleting FAILED records with delete_date set' do
      let!(:es_failed_delete) { create(:bd_failed_evidence_submission_for_deletion) }

      it 'deletes FAILED records with a past or current delete_date and reports metrics with status tag' do
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 0, tags: ['status:success'])
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 1, tags: ['status:failed'])
        expect(Rails.logger)
          .to receive(:info)
          .with("#{subject} deleted 1 of 1 EvidenceSubmission records (0 success, 1 failed)")

        subject.new.perform

        expect(EvidenceSubmission.where(id: es_failed_delete.id).count).to eq(0)
      end
    end

    context 'when FAILED records do not have delete_date set' do
      let!(:es_failed_no_delete) { create(:bd_evidence_submission_not_for_deletion) }

      it 'does not delete FAILED records without delete_date' do
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 0, tags: ['status:success'])
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 0, tags: ['status:failed'])
        expect(Rails.logger)
          .to receive(:info)
          .with("#{subject} deleted 0 of 1 EvidenceSubmission records (0 success, 0 failed)")

        subject.new.perform

        expect(EvidenceSubmission.where(id: es_failed_no_delete.id).count).to eq(1)
      end
    end

    context 'when there are mixed SUCCESS and FAILED records' do
      let!(:es_success_delete) do
        create(:bd_evidence_submission_for_deletion, job_class: 'BenefitsDocuments::Service')
      end
      let!(:es_failed_delete) { create(:bd_failed_evidence_submission_for_deletion) }
      let!(:es_failed_no_delete) { create(:bd_evidence_submission_not_for_deletion) }

      it 'deletes only records with delete_date set and reports correct metrics by status' do
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 1, tags: ['status:success'])
        expect(StatsD).to receive(:increment)
          .with('worker.cst.delete_evidence_submission_records.count', 1, tags: ['status:failed'])
        expect(Rails.logger)
          .to receive(:info)
          .with("#{subject} deleted 2 of 3 EvidenceSubmission records (1 success, 1 failed)")

        subject.new.perform

        expect(EvidenceSubmission.where(id: es_success_delete.id).count).to eq(0)
        expect(EvidenceSubmission.where(id: es_failed_delete.id).count).to eq(0)
        expect(EvidenceSubmission.where(id: es_failed_no_delete.id).count).to eq(1)
      end
    end

    context 'when an exception is thrown' do
      let(:error_message) { 'Error message' }

      before do
        allow(EvidenceSubmission).to receive(:all).and_raise(ActiveRecord::ActiveRecordError.new(error_message))
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
