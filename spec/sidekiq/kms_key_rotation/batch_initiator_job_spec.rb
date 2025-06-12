# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KmsKeyRotation::BatchInitiatorJob, type: :job do
  let(:job) { described_class.new }
  let!(:burial_claim_records) { create_list(:burial_claim, 6, needs_kms_rotation: true) }
  let!(:form_1095_b_records) { create(:form1095_b, needs_kms_rotation: true) }
  let!(:supplemental_claim_records) { create_list(:supplemental_claim, 5, needs_kms_rotation: true) }

  before do
    KmsKeyRotation::BatchInitiatorJob.send(:remove_const, :MAX_RECORDS_PER_BATCH)
    KmsKeyRotation::BatchInitiatorJob.const_set(:MAX_RECORDS_PER_BATCH, 10)
    KmsKeyRotation::BatchInitiatorJob.send(:remove_const, :MAX_RECORDS_PER_JOB)
    KmsKeyRotation::BatchInitiatorJob.const_set(:MAX_RECORDS_PER_JOB, 2)

    allow_any_instance_of(described_class).to receive(:models)
      .and_return([SavedClaim, Form1095B, AppealsApi::SupplementalClaim])
    allow_any_instance_of(KmsEncryptedModelPatch).to receive(:kms_version).and_return('other_version')

    KmsKeyRotation::RotateKeysJob.jobs.clear
  end

  describe '#perform' do
    context 'on the rotation date (Oct 12)' do
      before do
        allow(job).to receive(:rotation_date?).and_return(true)
      end

      it 'flags all eligible models for rotation' do
        expect(SavedClaim).to receive(:update_all).with(needs_kms_rotation: true)
        expect(Form1095B).to receive(:update_all).with(needs_kms_rotation: true)
        expect(AppealsApi::SupplementalClaim).to receive(:update_all).with(needs_kms_rotation: true)

        job.perform
      end

      it 'then enqueues RotateKeysJob jobs for each flagged record' do
        job.perform
        expect(KmsKeyRotation::RotateKeysJob.jobs.size).to eq(7)
      end
    end

    context 'when not the rotation date' do
      before do
        allow(job).to receive(:rotation_date?).and_return(false)
      end

      it 'does not flag any records for rotation' do
        expect(SavedClaim).not_to receive(:update_all)
        expect(Form1095B).not_to receive(:update_all)
        expect(AppealsApi::SupplementalClaim).not_to receive(:update_all)

        job.perform
      end

      it 'still enqueues RotateKeysJob jobs for pre-flagged records' do
        job.perform
        expect(KmsKeyRotation::RotateKeysJob.jobs.size).to eq(7)
      end
    end

    it 'creates RotateKeysJob jobs with the correct batch size' do
      allow(job).to receive(:rotation_date?).and_return(true)
      job.perform

      rotate_jobs = KmsKeyRotation::RotateKeysJob.jobs
      expect(rotate_jobs.size).to eq(7)
      expect(rotate_jobs.first['class']).to eq('KmsKeyRotation::RotateKeysJob')
      expect(rotate_jobs.first['args'].first.size).to eq(KmsKeyRotation::BatchInitiatorJob::MAX_RECORDS_PER_JOB)
    end
  end
end
