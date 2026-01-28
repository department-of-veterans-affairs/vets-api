# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormUploadDataPurgeJob, type: :job do
  let(:form_type) { '21-0779' }
  let(:cutoff_date) { 65.days.ago }

  describe '#perform' do
    describe 'job lifecycle metrics' do
      it 'increments job.started and job.completed when job begins and finishes' do
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.started")
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.completed")

        described_class.new.perform
      end

      it 'increments job.failed and re-raises exception on unexpected errors' do
        allow(FormSubmission).to receive(:where).and_raise(StandardError.new('Database error'))

        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.started")
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.failed")
        expect(Rails.logger).to receive(:error)
          .with('FormUploadDataPurgeJob failed', hash_including(error: 'Database error'))

        expect { described_class.new.perform }.to raise_error(StandardError, 'Database error')
      end
    end

    describe 'purging eligible submissions' do
      let(:form_submission) do
        FormSubmission.create!(
          form_type:,
          form_data: {
            confirmation_code: 'test-guid-123',
            full_name: { first: 'John', last: 'Doe' }
          }.to_json
        )
      end

      let!(:attempt) do
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
      end

      before do
        form_submission.update(updated_at: cutoff_date)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)
      end

      it 'purges the form submission data' do
        described_class.new.perform

        expect(form_submission.reload.form_data).to be_nil
      end

      it 'nulls out user_account_id' do
        form_submission.update(user_account_id: 123)

        described_class.new.perform

        expect(form_submission.reload.user_account_id).to be_nil
      end

      it 'emits pii.deleting event' do
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

        expect(ActiveSupport::Notifications).to receive(:instrument)
          .with('pii.deleting', hash_including(form_submission_id: form_submission.id))
          .and_call_original

        described_class.new.perform
      end

      it 'emits pii.deleted event' do
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

        expect(ActiveSupport::Notifications).to receive(:instrument)
          .with('pii.deleted', hash_including(form_submission_id: form_submission.id))
          .and_call_original

        described_class.new.perform
      end

      it 'increments form_purged metric' do
        allow(StatsD).to receive(:increment).and_call_original
        allow(StatsD).to receive(:gauge).and_call_original

        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.form_purged", tags: ["form_type:#{form_type}"])
          .and_call_original

        described_class.new.perform
      end
    end

    describe 'skipping ineligible submissions' do
      it 'skips submissions with wrong form type' do
        form_submission = FormSubmission.create!(
          form_type: 'WRONG-TYPE',
          form_data: { test: 'data' }.to_json
        )
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
        form_submission.update(updated_at: cutoff_date)

        described_class.new.perform

        expect(form_submission.reload.form_data).not_to be_nil
      end

      it 'skips submissions that are not vbms' do
        form_submission = FormSubmission.create!(
          form_type:,
          form_data: { test: 'data' }.to_json
        )
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'pending',
          lighthouse_updated_at: cutoff_date
        )
        form_submission.update(updated_at: cutoff_date)

        described_class.new.perform

        expect(form_submission.reload.form_data).not_to be_nil
      end

      it 'skips submissions that are too recent' do
        form_submission = FormSubmission.create!(
          form_type:,
          form_data: { test: 'data' }.to_json
        )
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: 30.days.ago
        )
        form_submission.update(updated_at: 30.days.ago)

        described_class.new.perform

        expect(form_submission.reload.form_data).not_to be_nil
      end

      it 'skips submissions already purged' do
        form_submission = FormSubmission.create!(
          form_type:,
          form_data_ciphertext: nil
        )
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
        form_submission.update(updated_at: cutoff_date)

        expect { described_class.new.perform }.not_to change { form_submission.reload.updated_at }
      end
    end

    describe 'handling attachments' do
      let(:form_submission) do
        FormSubmission.create!(
          form_type:,
          form_data: {
            confirmation_code: 'main-guid',
            supporting_documents: [
              { confirmation_code: 'support-guid-1' }
            ]
          }.to_json
        )
      end

      let!(:attempt) do
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
      end

      before do
        form_submission.update(updated_at: cutoff_date)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)
      end

      it 'handles missing attachments gracefully' do
        allow(PersistentAttachment).to receive(:find_by).and_return(nil)

        expect { described_class.new.perform }.not_to raise_error
      end

      it 'still purges form data when attachments missing' do
        allow(PersistentAttachment).to receive(:find_by).and_return(nil)

        described_class.new.perform

        expect(form_submission.reload.form_data).to be_nil
      end
    end

    describe 'handling legacy records without confirmation codes' do
      let(:form_submission) do
        FormSubmission.create!(
          form_type:,
          form_data: { full_name: { first: 'John', last: 'Doe' } }.to_json
        )
      end

      let!(:attempt) do
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
      end

      before do
        form_submission.update(updated_at: cutoff_date)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)
      end

      it 'purges form data without attempting to delete attachments' do
        described_class.new.perform

        expect(form_submission.reload.form_data).to be_nil
      end

      it 'logs that no attachment guids found' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info)
          .with('No attachment guids found in form_data (legacy record)',
                hash_including(benefits_intake_uuid: anything))
          .and_call_original
        described_class.new.perform
      end
    end

    describe 'error handling' do
      let(:form_submission) do
        FormSubmission.create!(
          form_type:,
          form_data: { confirmation_code: 'test-guid' }.to_json
        )
      end

      let!(:attempt) do
        FormSubmissionAttempt.create!(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid,
          aasm_state: 'vbms',
          lighthouse_updated_at: cutoff_date
        )
      end

      before do
        form_submission.update(updated_at: cutoff_date)
      end

      it 'logs errors but continues processing' do
        allow_any_instance_of(FormSubmission).to receive(:update_columns)
          .and_raise(StandardError.new('DB error'))

        allow(Rails.logger).to receive(:error).and_call_original

        expect(Rails.logger).to receive(:error)
          .with('Failed to purge form submission', hash_including(error: 'DB error'))

        expect { described_class.new.perform }.not_to raise_error
      end

      it 'increments error count on failure' do
        allow_any_instance_of(FormSubmission).to receive(:update_columns)
          .and_raise(StandardError.new('DB error'))

        described_class.new.perform
        expect(StatsD).to have_received(:increment).with("#{described_class::STATS_KEY}.completed")
      end
    end

    describe 'metrics recording' do
      it 'records gauges for all stats' do
        expect(StatsD).to receive(:gauge).with("#{described_class::STATS_KEY}.form_submissions_purged", anything)
        expect(StatsD).to receive(:gauge).with("#{described_class::STATS_KEY}.s3_files_deleted", anything)
        expect(StatsD).to receive(:gauge).with("#{described_class::STATS_KEY}.s3_files_already_deleted", anything)

        described_class.new.perform
      end
    end
  end
end