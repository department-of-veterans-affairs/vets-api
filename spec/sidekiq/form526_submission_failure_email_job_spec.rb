# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526SubmissionFailureEmailJob, type: :job do
  subject { described_class }

  let(:callback_metadata) do
    { callback_metadata: { form_number: 'form526',
                           notification_type: 'error',
                           statsd_tags: {
                             function: '526_backup_submission_to_lighthouse',
                             service: 'disability-application'
                           } } }
  end
  let(:email_service) { double('VaNotify::Service') }
  let(:timestamp) { Time.now.utc }
  let(:failure_timestamp) { timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.') }

  before do
    Sidekiq::Job.clear_all
    allow(VaNotify::Service)
      .to receive(:new)
      .with(Settings.vanotify.services.benefits_disability.api_key, callback_metadata)
      .and_return(email_service)
  end

  describe '#perform' do
    context 'when a user has additional forms and files with their submission' do
      let!(:form526_submission) { create(:form526_submission, :with_uploads_and_ancillary_forms) }

      let(:expected_params) do
        {
          email_address: 'test@email.com',
          template_id: 'form526_submission_failure_notification_template_id',
          personalisation: {
            first_name: form526_submission.get_first_name,
            date_submitted: form526_submission.format_creation_time_for_mailers,
            date_of_failure: failure_timestamp,
            files_submitted: ['extXas.pdf', 'extXas.pdf', 'extXas.pdf'],
            forms_submitted: [
              'VA Form 21-4142',
              'VA Form 21-0781',
              'VA Form 21-0781a',
              'VA Form 21-8940'
            ]
          }
        }
      end

      context 'when a timestamp is not passed' do
        it 'marks the current time as the date_of_failure' do
          Timecop.freeze(timestamp) do
            expect(email_service).to receive(:send_email).with(expected_params)

            subject.perform_async(form526_submission.id)
            subject.drain
          end
        end
      end

      it 'dispatches a failure notification email with the expected params' do
        Timecop.freeze(timestamp) do
          expect(email_service).to receive(:send_email).with(expected_params)

          subject.perform_async(form526_submission.id, timestamp.to_s)
          subject.drain
        end
      end

      it 'creates a remediation record for the submission' do
        Timecop.freeze(timestamp) do
          allow(email_service).to receive(:send_email)
          expect { subject.new.perform(form526_submission.id) }.to change(Form526SubmissionRemediation, :count)
          remediation = Form526SubmissionRemediation.where(form526_submission_id: form526_submission.id)
          expect(remediation.present?).to be true
        end
      end
    end

    context 'when a user has no additional forms with their submission' do
      let!(:form526_submission) { create(:form526_submission, :with_uploads) }
      let(:expected_params) do
        {
          email_address: 'test@email.com',
          template_id: 'form526_submission_failure_notification_template_id',
          personalisation: {
            first_name: form526_submission.get_first_name,
            date_submitted: form526_submission.format_creation_time_for_mailers,
            date_of_failure: failure_timestamp,
            files_submitted: ['extXas.pdf', 'extXas.pdf', 'extXas.pdf'],
            forms_submitted: 'None'
          }
        }
      end

      before do
        form526_submission.form['form526_uploads'].each do |upload|
          create(:supporting_evidence_attachment, :with_file_data, guid: upload['confirmationCode'])
        end
      end

      it 'replaces the forms list variable with a placeholder' do
        Timecop.freeze(timestamp) do
          expect(email_service).to receive(:send_email).with(expected_params)

          subject.perform_async(form526_submission.id, timestamp.to_s)
          subject.drain
        end
      end
    end

    context 'when a user has no additional user-uploaded files with their submission' do
      context 'when using v1 of form 0781' do
        let(:expected_params) do
          {
            email_address: 'test@email.com',
            template_id: 'form526_submission_failure_notification_template_id',
            personalisation: {
              first_name: form526_submission.get_first_name,
              date_submitted: form526_submission.format_creation_time_for_mailers,
              date_of_failure: failure_timestamp,
              files_submitted: 'None',
              forms_submitted: [
                'VA Form 21-4142',
                'VA Form 21-0781',
                'VA Form 21-0781a',
                'VA Form 21-8940'
              ]
            }
          }
        end

        let!(:form526_submission) { create(:form526_submission, :with_everything) }

        it 'replaces the files list variable with a placeholder' do
          Timecop.freeze(timestamp) do
            expect(email_service).to receive(:send_email).with(expected_params)

            subject.perform_async(form526_submission.id, timestamp.to_s)
            subject.drain
          end
        end
      end

      context 'when using v2 of form 0781' do
        let(:expected_params) do
          {
            email_address: 'test@email.com',
            template_id: 'form526_submission_failure_notification_template_id',
            personalisation: {
              first_name: form526_submission.get_first_name,
              date_submitted: form526_submission.format_creation_time_for_mailers,
              date_of_failure: failure_timestamp,
              files_submitted: 'None',
              forms_submitted: [
                'VA Form 21-4142',
                'VA Form 21-0781',
                'VA Form 21-8940'
              ]
            }
          }
        end

        let!(:form526_submission) { create(:form526_submission, :with_0781v2) }

        it 'replaces the files list variable with a placeholder' do
          Timecop.freeze(timestamp) do
            expect(email_service).to receive(:send_email).with(expected_params)

            subject.perform_async(form526_submission.id, timestamp.to_s)
            subject.drain
          end
        end
      end
    end
  end

  describe 'logging' do
    let!(:form526_submission) { create(:form526_submission, :with_uploads_and_ancillary_forms) }

    let(:timestamp) { Time.now.utc }
    let(:tags) { described_class::DD_ZSF_TAGS }

    context 'on success' do
      before do
        allow(email_service).to receive(:send_email)
      end

      it 'increments StatsD' do
        expect(StatsD).to receive(:increment).with("#{described_class::STATSD_PREFIX}.success")
        subject.new.perform(form526_submission.id)
        subject.drain
      end

      it 'logs success' do
        Timecop.freeze(timestamp) do
          expect(Rails.logger).to receive(:info).with(
            'Form526SubmissionFailureEmailJob notification dispatched',
            { form526_submission_id: form526_submission.id, timestamp: }
          )
          subject.new.perform(form526_submission.id)
        end
      end
    end

    context 'on failure' do
      let(:error_message) { 'oh gosh oh jeeze oh no' }
      let(:expected_log) do
        [
          'Form526SubmissionFailureEmailJob notification dispatched',
          {
            form526_submission_id: form526_submission.id,
            error_message:,
            timestamp:
          }
        ]
      end

      before do
        allow(email_service).to receive(:send_email).and_raise error_message
      end

      it 'increments StatsD' do
        expect(StatsD).to receive(:increment).with("#{described_class::STATSD_PREFIX}.error")
        expect { subject.new.perform(form526_submission.id) }.to raise_error(error_message)
      end

      it 'logs error' do
        Timecop.freeze(timestamp) do
          expect(Rails.logger).to receive(:error).with(
            'Form526SubmissionFailureEmailJob notification failed',
            {
              form526_submission_id: form526_submission.id,
              error_message:,
              timestamp:
            }
          )
          expect { subject.new.perform(form526_submission.id) }.to raise_error(error_message)
        end
      end
    end

    context 'on exhaustion' do
      let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }
      let(:expected_log) do
        {
          job_id: form526_job_status.job_id,
          form526_submission_id: form526_submission.id,
          error_class: 'WhoopsieDasiy',
          error_message: 'aww shucks',
          timestamp:
        }
      end
      let(:exhaustion_block_args) do
        {
          'jid' => form526_job_status.job_id,
          'args' => [form526_submission.id],
          'error_class' => 'WhoopsieDasiy',
          'error_message' => 'aww shucks'
        }
      end

      it 'logs' do
        Timecop.freeze(timestamp) do
          subject.within_sidekiq_retries_exhausted_block(exhaustion_block_args) do
            expect(Rails.logger).to receive(:warn).with(
              'Form526SubmissionFailureEmailJob retries exhausted',
              expected_log
            )
          end
        end
      end

      it 'increments StatsD' do
        Timecop.freeze(timestamp) do
          subject.within_sidekiq_retries_exhausted_block(exhaustion_block_args) do
            expect(StatsD).to receive(:increment).with("#{described_class::STATSD_PREFIX}.exhausted")
            expect(StatsD).to receive(:increment).with('silent_failure', tags: described_class::DD_ZSF_TAGS)
          end
        end
      end
    end
  end
end
