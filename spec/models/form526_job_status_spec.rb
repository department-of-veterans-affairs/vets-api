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
end
