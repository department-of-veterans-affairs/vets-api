# frozen_string_literal: true

require 'rails_helper'

GeneralError = Class.new(StandardError)

RSpec.describe KmsKeyRotation::BatchInitiatorJob, type: :job do
  let(:job) { described_class.new }
  let!(:burial_claim_records) { create_list(:burial_claim, 6) }
  let!(:form_1095_b_records) { create(:form1095_b) }
  let!(:supplemental_claim_records) { create_list(:supplemental_claim, 5) }

  before do
    KmsKeyRotation::BatchInitiatorJob.send(:remove_const, :RECORDS_PER_BATCH)
    KmsKeyRotation::BatchInitiatorJob.const_set(:RECORDS_PER_BATCH, 10)
    KmsKeyRotation::BatchInitiatorJob.send(:remove_const, :RECORDS_PER_JOB)
    KmsKeyRotation::BatchInitiatorJob.const_set(:RECORDS_PER_JOB, 2)
  end

  describe '#perform' do
    before do
      allow_any_instance_of(described_class).to receive(:models)
        .and_return([SavedClaim, Form1095B, AppealsApi::SupplementalClaim])
      allow_any_instance_of(KmsEncryptedModelPatch).to receive(:kms_version).and_return('other_version')
    end

    it 'batches jobs for records needing rotation' do
      job.perform

      # RECORDS_PER_BATCH / RECORDS_PER_JOB = 5 jobs
      expect(KmsKeyRotation::RotateKeysJob.jobs.size).to eq(5)
    end

    it 'creates RotateKeysJob jobs with batched_gids as args' do
      job.perform

      rotate_jobs = KmsKeyRotation::RotateKeysJob.jobs
      expect(rotate_jobs.size).to eq(5)

      job_class = rotate_jobs.first['class']
      expect(job_class).to eq('KmsKeyRotation::RotateKeysJob')

      job_args = rotate_jobs.first['args'].first
      expect(job_args.keys).to eq(['gids'])
      expect(job_args['gids'].size).to eq(KmsKeyRotation::BatchInitiatorJob::RECORDS_PER_JOB)
    end

    it 're-raises errors raised while batching gids' do
      allow_any_instance_of(Array).to receive(:each_slice).and_raise(GeneralError)

      expect { job.perform }.to raise_error(GeneralError)
    end
  end

  describe '#get_records' do
    before do
      allow_any_instance_of(KmsEncryptedModelPatch).to receive(:kms_version).and_return('0000')
    end

    it 'retrieves all records for a single model (until cap of RECORDS_PER_BATCH)' do
      allow_any_instance_of(described_class).to receive(:models).and_return([SavedClaim])
      records = job.records

      expect(records.size).to eq(6)
    end

    it 'retrieves all records for multiple models (until cap of RECORDS_PER_BATCH)' do
      allow_any_instance_of(described_class).to receive(:models).and_return([SavedClaim, Form1095B])
      records = job.records

      expect(records.size).to eq(7)
    end

    it 'retrieves all records for all models up until RECORDS_PER_BATCH' do
      allow_any_instance_of(described_class).to receive(:models)
        .and_return([SavedClaim, Form1095B, AppealsApi::SupplementalClaim])
      records = job.records

      expect(records.size).to eq(KmsKeyRotation::BatchInitiatorJob::RECORDS_PER_BATCH)
    end
  end
end
