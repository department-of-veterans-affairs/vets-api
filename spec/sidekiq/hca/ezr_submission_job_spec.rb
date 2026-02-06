# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq'
require 'sidekiq/job_retry'

RSpec.describe HCA::EzrSubmissionJob, type: :job do
  let(:user) { create(:evss_user, :loa3, icn: '1013032368V065534') }
  let(:form) do
    get_fixture('form1010_ezr/valid_form')
  end
  let(:encrypted_form) do
    HealthCareApplication::LOCKBOX.encrypt(form.to_json)
  end
  let(:ezr_service) { double }
  let(:tags) { described_class::DD_ZSF_TAGS }
  let(:form_id) { described_class::FORM_ID }
  let(:api_key) { Settings.vanotify.services.health_apps_1010.api_key }
  let(:failure_email_template_id) { Settings.vanotify.services.health_apps_1010.template_id.form1010_ezr_failure_email }
  let(:failure_email_template_params) do
    [
      form['email'],
      failure_email_template_id,
      {
        'salutation' => "Dear #{form.dig('veteranFullName', 'first')},"
      },
      api_key,
      {
        callback_metadata: {
          notification_type: 'error',
          form_number: form_id,
          statsd_tags: tags
        }
      }
    ]
  end

  def expect_submission_failure_email_and_statsd_increments
    expect(VANotify::EmailJob).to receive(:perform_async).with(*failure_email_template_params)
    expect(StatsD).to receive(:increment).with('api.1010ezr.submission_failure_email_sent')
  end

  def dont_expect_submission_failure_email_and_statsd_increments
    expect(VANotify::EmailJob).not_to receive(:perform_async)
    expect(StatsD).not_to receive(:increment).with('api.1010ezr.submission_failure_email_sent')
  end

  describe 'when retries are exhausted' do
    before do
      Flipper.enable(:ezr_use_va_notify_on_submission_failure) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    after do
      Flipper.disable(:ezr_use_va_notify_on_submission_failure) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    context 'when the parsed form is not present' do
      it 'only increments StatsD' do
        msg = {
          'args' => [HealthCareApplication::LOCKBOX.encrypt({}.to_json), nil]
        }

        described_class.within_sidekiq_retries_exhausted_block(msg) do
          allow(StatsD).to receive(:increment)
          expect(StatsD).to receive(:increment).with('api.1010ezr.failed_wont_retry')
          expect(described_class).not_to receive(:send_failure_email)
        end
      end
    end

    context 'when the parsed form is present' do
      context 'the send failure email flipper is enabled' do
        it 'tracks the errors and sends the failure email' do
          msg = {
            'args' => [encrypted_form, nil]
          }

          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(VANotify::EmailJob).to receive(:perform_async)
            expect(StatsD).to receive(:increment).with('api.1010ezr.failed_wont_retry')
            expect_submission_failure_email_and_statsd_increments
          end

          pii_log = PersonalInformationLog.last
          expect(pii_log.error_class).to eq('Form1010Ezr FailedWontRetry')
          expect(pii_log.data).to eq(form)
        end

        it 'logs the errors' do
          msg = {
            'args' => [encrypted_form, nil]
          }

          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(VANotify::EmailJob).to receive(:perform_async)
            expect_any_instance_of(Vets::SharedLogging).to receive(:log_message_to_rails).with(
              '[10-10EZR] total failure',
              :error,
              {
                first_initial: 'F',
                middle_initial: 'M',
                last_initial: 'Z'
              }
            )
          end
        end

        it 'does not send the failure notification if email is blank' do
          form['email'] = nil
          msg = {
            'args' => [encrypted_form, nil]
          }

          described_class.within_sidekiq_retries_exhausted_block(msg) do
            expect(VANotify::EmailJob).not_to receive(:perform_async)
            expect(StatsD).not_to receive(:increment).with('api.1010ezr.submission_failure_email_sent')
          end
        end
      end

      context 'the send failure email flipper is disabled' do
        it 'does not send the email' do
          msg = {
            'args' => [encrypted_form, nil]
          }
          Flipper.disable(:ezr_use_va_notify_on_submission_failure) # rubocop:disable Project/ForbidFlipperToggleInSpecs

          described_class.within_sidekiq_retries_exhausted_block(msg) do
            expect(VANotify::EmailJob).not_to receive(:perform_async).with(*failure_email_template_params)
            expect(StatsD).not_to receive(:increment).with('api.1010ezr.submission_failure_email_sent')
          end
        end
      end
    end
  end

  describe '#perform' do
    subject do
      described_class.new.perform(encrypted_form, user.uuid)
    end

    before do
      allow(User).to receive(:find).with(user.uuid).and_return(user)
      allow(Form1010Ezr::Service).to receive(:new).with(user).once.and_return(ezr_service)
    end

    context 'when submission has an error' do
      context 'with an enrollment system validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it "increments StatsD, creates a 'PersonalInformationLog', logs the submission failure, " \
           'and sends a failure email' do
          allow(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)
          allow(StatsD).to receive(:increment)

          expect(StatsD).to receive(:increment).with('api.1010ezr.enrollment_system_validation_error')
          expect_submission_failure_email_and_statsd_increments

          subject

          personal_information_log = PersonalInformationLog.last
          expect(personal_information_log.error_class).to eq('Form1010Ezr EnrollmentSystemValidationFailure')
          expect(personal_information_log.data).to eq(form)
        end

        it 'logs the error' do
          allow(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)
          expect(HCA::EzrSubmissionJob).to receive(:log_exception_to_rails)
          expect(Form1010Ezr::Service).to receive(:log_submission_failure).with(
            form,
            '[10-10EZR] failure'
          )
          subject
        end
      end

      context 'with an Ox::ParseError' do
        let(:error_msg) { 'invalid format, elements overlap at line 1, column 212 [parse.c:626]' }
        let(:full_log_msg) { "Form1010Ezr FailedDidNotRetry: #{error_msg}" }

        before do
          allow(User).to receive(:find).with(user.uuid).and_return(user)
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
          allow(VANotify::EmailJob).to receive(:perform_async)
          allow(Form1010Ezr::Service).to receive(:new).with(user).once.and_return(ezr_service)
          allow(ezr_service).to receive(:submit_sync).and_raise(Ox::ParseError.new(error_msg))
        end

        it 'increments StatsD, creates a PersonalInformationLog, logs the error, and does not retry' do
          expect(StatsD).to receive(:increment).with('api.1010ezr.failed_did_not_retry')
          expect(Rails.logger).to receive(:info).with(full_log_msg)
          expect(PersonalInformationLog).to receive(:create!).with(
            data: form,
            error_class: 'Form1010Ezr FailedDidNotRetry'
          )
          # The Sidekiq::JobRetry::Skip error will fail the job and not retry it
          expect { subject }.to raise_error(Sidekiq::JobRetry::Skip)
        end

        context 'when the send failure email flipper is enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:ezr_use_va_notify_on_submission_failure).and_return(true)
          end

          it 'sends a failure email, and does not retry' do
            expect { subject }.to raise_error(Sidekiq::JobRetry::Skip)
          end
        end

        context 'when the send failure email flipper is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:ezr_use_va_notify_on_submission_failure).and_return(false)
          end

          it 'sends a failure email, and does not retry' do
            dont_expect_submission_failure_email_and_statsd_increments
            expect { subject }.to raise_error(Sidekiq::JobRetry::Skip)
          end
        end
      end

      context 'with any other error' do
        let(:error) { Common::Client::Errors::HTTPError }

        it 'logs the retry' do
          allow(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)

          expect { subject }.to trigger_statsd_increment(
            'api.1010ezr.async.retries'
          ).and raise_error(error)
        end
      end
    end

    context 'with a successful submission' do
      it 'calls the service' do
        expect(ezr_service).to receive(:submit_sync).with(form)

        subject
      end
    end
  end
end
