# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail, type: :job do
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
      form526_submission.created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'dispatches a failure notification email with an obscured filename' do
      obscured_filename = 'sm_***e1.jpg'

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

      subject.perform(form526_submission.id, form_attachment.guid)
    end

    it 'logs to the Rails logger' do
      allow(notification_client).to receive(:send_email)
      exhaustion_time = Time.new(1985, 10, 26).utc

      Timecop.freeze(exhaustion_time) do
        expect(Rails.logger).to receive(:info).with(
          'Form526DocumentUploadFailureEmail notification dispatched',
          {
            obscured_filename: 'sm_***e1.jpg',
            form526_submission_id: form526_submission.id,
            supporting_evidence_attachment_guid: form_attachment.guid,
            timestamp: exhaustion_time
          }
        )

        subject.perform(form526_submission.id, form_attachment.guid)
      end
    end

    it 'increments a Statsd metric' do
      allow(notification_client).to receive(:send_email)

      expect { subject.perform(form526_submission.id, form_attachment.guid) }.to trigger_statsd_increment(
        'api.form_526.veteran_notifications.document_upload_failure_email.success'
      )
    end
  end

  context 'when all retries are exhausted' do
    let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 123) }
    let(:retry_params) do
      {
        'jid' => 123,
        'error_class' => 'JennyNotFound',
        'args' => [form526_submission.id, form_attachment.guid]
      }
    end

    let(:exhaustion_time) { DateTime.new(1985, 10, 26).utc }

    before do
      allow(notification_client).to receive(:send_email)
    end

    it 'increments a StatsD exhaustion metric, logs to the Rails logger and updates the job status' do
      Timecop.freeze(exhaustion_time) do
        described_class.within_sidekiq_retries_exhausted_block(retry_params) do
          expect(Rails.logger).to receive(:warn).with(
            'Form526DocumentUploadFailureEmail retries exhausted',
            {
              job_id: 123,
              error_class: 'JennyNotFound',
              timestamp: exhaustion_time,
              form526_submission_id: form526_submission.id,
              supporting_evidence_attachment_guid: form_attachment.guid
            }
          ).and_call_original
          expect(StatsD).to receive(:increment).with(
            'api.form_526.veteran_notifications.document_upload_failure_email.exhausted'
          )
        end

        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end
    end
  end
end
