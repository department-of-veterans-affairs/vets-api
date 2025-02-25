# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail, type: :job do
  subject { described_class }

  let!(:form526_submission) { create(:form526_submission) }
  let(:notification_client) { double('Notifications::Client') }
  let(:formatted_submit_date) do
    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    form526_submission.created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end

  before do
    Sidekiq::Job.clear_all
    allow(Notifications::Client).to receive(:new).and_return(notification_client)
  end

  describe '#perform' do
    it 'dispatches a failure notification email' do
      expect(notification_client).to receive(:send_email).with(
        # Email address and first_name are from our User fixtures
        # form0781_upload_failure_notification_template_id is a placeholder in settings.yml
        {
          email_address: 'test@email.com',
          template_id: 'form0781_upload_failure_notification_template_id',
          personalisation: {
            first_name: 'BEYONCE',
            date_submitted: formatted_submit_date
          }
        }
      )

      subject.perform_async(form526_submission.id)
      subject.drain
    end
  end

  describe 'logging' do
    before do
      allow(notification_client).to receive(:send_email).and_return({})
    end

    it 'increments StatsD success & silent failure avoided metrics' do
      expect do
        subject.perform_async(form526_submission.id)
        subject.drain
      end.to trigger_statsd_increment(
        'api.form_526.veteran_notifications.form0781_upload_failure_email.success'
      )
    end

    it 'logs to the Rails logger' do
      allow(Rails.logger).to receive(:info)

      exhaustion_time = Time.new(1985, 10, 26).utc

      Timecop.freeze(exhaustion_time) do
        subject.perform_async(form526_submission.id)
        subject.drain

        expect(Rails.logger).to have_received(:info).with(
          'Form0781DocumentUploadFailureEmail notification dispatched',
          {
            form526_submission_id: form526_submission.id,
            timestamp: exhaustion_time,
            va_notify_response: {}
          }
        )
      end
    end

    it 'creates a Form526JobStatus' do
      expect do
        subject.perform_async(form526_submission.id)
        subject.drain
      end.to change(Form526JobStatus, :count).by(1)
    end

    context 'when an error throws when sending an email' do
      before do
        allow_any_instance_of(VaNotify::Service).to receive(:send_email).and_raise(Common::Client::Errors::ClientError)
      end

      it 'passes the error to the included JobTracker retryable_error_handler and re-raises the error' do
        # Sidekiq::Form526JobStatusTracker::JobTracker is included in this job's inheritance hierarchy
        expect_any_instance_of(
          Sidekiq::Form526JobStatusTracker::JobTracker
        ).to receive(:retryable_error_handler).with(an_instance_of(Common::Client::Errors::ClientError))

        expect do
          subject.perform_async(form526_submission.id)
          subject.drain
        end.to raise_error(Common::Client::Errors::ClientError)
      end
    end
  end

  context 'when retries are exhausted' do
    let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 123) }
    let(:retry_params) do
      {
        'jid' => 123,
        'error_class' => 'JennyNotFound',
        'error_message' => 'I tried to call you before but I lost my nerve',
        'args' => [form526_submission.id]
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
            'Form0781DocumentUploadFailureEmail retries exhausted',
            {
              job_id: 123,
              error_class: 'JennyNotFound',
              error_message: 'I tried to call you before but I lost my nerve',
              timestamp: exhaustion_time,
              form526_submission_id: form526_submission.id
            }
          ).and_call_original

          expect(StatsD).to receive(:increment).with(
            'api.form_526.veteran_notifications.form0781_upload_failure_email.exhausted'
          ).ordered

          expect(StatsD).to receive(:increment).with(
            'silent_failure',
            tags: [
              'service:disability-application',
              'function:526_form_0781_failure_email_queuing'
            ]
          ).ordered
        end

        expect(form526_job_status.reload.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end
    end
  end
end
