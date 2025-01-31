# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail, type: :job do
  subject { described_class }

  let!(:form526_submission) do
    create(
      :form526_submission,
      :with_uploads
    )
  end

  let(:upload_data) { [form526_submission.form[Form526Submission::FORM_526_UPLOADS].first] }
  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
  let!(:form_attachment) do
    sea = SupportingEvidenceAttachment.new(
      guid: upload_data.first['confirmationCode']
    )

    sea.set_file_data!(file)
    sea.save!
    sea
  end

  let(:notification_client) { double('Notifications::Client') }

  before do
    Sidekiq::Job.clear_all
    allow(Notifications::Client).to receive(:new).and_return(notification_client)
  end

  describe '#perform' do
    let(:formatted_submit_date) do
      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      form526_submission.created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    let(:obscured_filename) { 'sm_XXXe1.jpg' }

    it 'dispatches a failure notification email with an obscured filename' do
      expect(notification_client).to receive(:send_email).with(
        # Email address and first_name are from our User fixtures
        # form526_document_upload_failure_notification_template_id is a placeholder in settings.yml
        {
          email_address: 'test@email.com',
          template_id: 'form526_document_upload_failure_notification_template_id',
          personalisation: {
            first_name: 'BEYONCE',
            filename: obscured_filename,
            date_submitted: formatted_submit_date
          }
        }
      )

      subject.perform_async(form526_submission.id, form_attachment.guid)
      subject.drain
    end

    describe 'logging' do
      before do
        allow(notification_client).to receive(:send_email).and_return({})
      end

      it 'logs to the Rails logger' do
        # Necessary to allow multiple logging statements and test has_received on ours
        # Required as other logging occurs (in lib/sidekiq/form526_job_status_tracker/job_tracker.rb callbacks)
        allow(Rails.logger).to receive(:info)
        exhaustion_time = Time.new(1985, 10, 26).utc

        Timecop.freeze(exhaustion_time) do
          subject.perform_async(form526_submission.id, form_attachment.guid)
          subject.drain

          expect(Rails.logger).to have_received(:info).with(
            'Form526DocumentUploadFailureEmail notification dispatched',
            {
              obscured_filename:,
              form526_submission_id: form526_submission.id,
              supporting_evidence_attachment_guid: form_attachment.guid,
              timestamp: exhaustion_time,
              va_notify_response: {}
            }
          )
        end
      end

      it 'increments StatsD success & silent failure avoided metrics' do
        expect do
          subject.perform_async(form526_submission.id, form_attachment.guid)
          subject.drain
        end.to trigger_statsd_increment(
          'api.form_526.veteran_notifications.document_upload_failure_email.success'
        )
      end

      it 'creates a Form526JobStatus' do
        expect do
          subject.perform_async(form526_submission.id, form_attachment.guid)
          subject.drain
        end.to change(Form526JobStatus, :count).by(1)
      end
    end
  end

  context 'when all retries are exhausted' do
    let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 123) }
    let(:retry_params) do
      {
        'jid' => 123,
        'error_class' => 'JennyNotFound',
        'error_message' => 'I tried to call you before but I lost my nerve',
        'args' => [form526_submission.id, form_attachment.guid]
      }
    end

    let(:exhaustion_time) { DateTime.new(1985, 10, 26).utc }

    before do
      allow(notification_client).to receive(:send_email)
    end

    it 'increments StatsD exhaustion & silent failure metrics, logs to the Rails logger and updates the job status' do
      Timecop.freeze(exhaustion_time) do
        described_class.within_sidekiq_retries_exhausted_block(retry_params) do
          expect(Rails.logger).to receive(:warn).with(
            'Form526DocumentUploadFailureEmail retries exhausted',
            {
              job_id: 123,
              error_class: 'JennyNotFound',
              error_message: 'I tried to call you before but I lost my nerve',
              timestamp: exhaustion_time,
              form526_submission_id: form526_submission.id,
              supporting_evidence_attachment_guid: form_attachment.guid
            }
          ).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.form_526.veteran_notifications.document_upload_failure_email.exhausted'
          ).ordered

          expect(StatsD).to receive(:increment).with(
            'silent_failure',
            tags: [
              'service:disability-application',
              'function:526_evidence_upload_failure_email_queuing'
            ]
          ).ordered
        end

        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end
    end
  end
end
