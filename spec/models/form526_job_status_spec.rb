# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526JobStatus do
  describe '.upsert' do
    let(:form526_submission) { create(:form526_submission) }
    let(:jid) { SecureRandom.uuid }
    let(:values) do
      {
        form526_submission_id: form526_submission.id,
        job_id: jid,
        job_class: 'SubmitForm526',
        status: Form526JobStatus::STATUS[:success],
        updated_at: Time.now.utc
      }
    end

    it 'creates a record' do
      expect do
        Form526JobStatus.upsert(values, unique_by: :job_id)
      end.to change(Form526JobStatus, :count).by(1)
    end
  end

  describe '#success?' do
    it 'returns true for new success statuses' do
      success_statuses = %w[pdf_found_later pdf_success_on_backup_path pdf_manually_uploaded]
      success_statuses.each do |status|
        job_status = described_class.new(status:)
        expect(job_status.success?).to be true
      end
    end

    it 'returns false for failure statuses' do
      failure_statuses = %w[non_retryable_error exhausted]
      failure_statuses.each do |status|
        job_status = described_class.new(status:)
        expect(job_status.success?).to be false
      end
    end
  end
end
