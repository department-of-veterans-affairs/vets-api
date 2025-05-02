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
  end

  describe '#perform' do
    before do
      allow_any_instance_of(described_class).to receive(:models)
        .and_return([SavedClaim, Form1095B, AppealsApi::SupplementalClaim])
      allow_any_instance_of(KmsEncryptedModelPatch).to receive(:kms_version).and_return('other_version')
    end

    it 'batches jobs for records needing rotation' do
      job.perform

      expect(KmsKeyRotation::RotateKeysJob.jobs.size).to eq(7)
    end

    it 'creates RotateKeysJob jobs with batched_gids as args' do
      job.perform

      rotate_jobs = KmsKeyRotation::RotateKeysJob.jobs
      expect(rotate_jobs.size).to eq(7)

      job_class = rotate_jobs.first['class']
      expect(job_class).to eq('KmsKeyRotation::RotateKeysJob')

      job_args = rotate_jobs.first['args'].first
      expect(job_args.size).to eq(KmsKeyRotation::BatchInitiatorJob::MAX_RECORDS_PER_JOB)
    end
  end
end
