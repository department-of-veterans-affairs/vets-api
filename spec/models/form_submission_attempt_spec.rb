# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormSubmissionAttempt, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:form_submission) }
  end

  describe 'state machine' do
    before { allow_any_instance_of(SimpleFormsApi::NotificationEmail).to receive(:send) }

    let(:config) do
      {
        form_data: anything,
        form_number: anything,
        date_submitted: anything,
        lighthouse_updated_at: anything,
        confirmation_number: anything
      }
    end

    context 'transitioning to a failure state' do
      let(:notification_type) { :error }

      it 'transitions to a failure state' do
        form_submission_attempt = create(:form_submission_attempt)

        expect(form_submission_attempt)
          .to transition_from(:pending).to(:failure).on_event(:fail)
      end

      context 'is a simple form' do
        let(:form_submission) { build(:form_submission, form_type: '21-4142') }

        it 'sends an error email' do
          notification_email = double
          allow(notification_email).to receive(:send)
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).with(
            config,
            notification_type:,
            user_account: anything
          ).and_return(notification_email)
          form_submission_attempt = create(:form_submission_attempt, form_submission:)

          form_submission_attempt.fail!

          expect(notification_email).to have_received(:send)
        end
      end

      context 'is not a simple form' do
        let(:form_submission) { build(:form_submission, form_type: 'some-other-form') }

        it 'does not send an error email' do
          allow(SimpleFormsApi::NotificationEmail).to receive(:new)
          form_submission_attempt = create(:form_submission_attempt, form_submission:)

          form_submission_attempt.fail!

          expect(SimpleFormsApi::NotificationEmail).not_to have_received(:new)
        end

        context 'is a form526_form4142 form' do
          let(:vanotify_client) { instance_double(VaNotify::Service) }
          let!(:email_klass) { EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail }
          let!(:form526_submission) { create(:form526_submission) }
          let!(:form526_form4142_form_submission) do
            create(:form_submission, saved_claim_id: form526_submission.saved_claim_id,
                                     form_type: CentralMail::SubmitForm4142Job::FORM4142_FORMSUBMISSION_TYPE)
          end
          let!(:form_submission_attempt) do
            FormSubmissionAttempt.create(form_submission: form526_form4142_form_submission)
          end

          it 'sends an 4142 error email when it is not a SimpleFormsApi form and flippers are on' do
            Flipper.enable(CentralMail::SubmitForm4142Job::POLLING_FLIPPER_KEY)
            Flipper.enable(CentralMail::SubmitForm4142Job::POLLED_FAILURE_EMAIL)

            allow(VaNotify::Service).to receive(:new).and_return(vanotify_client)
            allow(vanotify_client).to receive(:send_email).and_return(OpenStruct.new(id: 'some_id'))

            with_settings(Settings.vanotify.services.benefits_disability, { api_key: 'test_service_api_key' }) do
              expect do
                form_submission_attempt.fail!
                email_klass.drain
              end.to trigger_statsd_increment("#{email_klass::STATSD_METRIC_PREFIX}.success")
                .and change(Form526JobStatus, :count).by(1)

              job_tracking = Form526JobStatus.last
              expect(job_tracking.form526_submission_id).to eq(form526_submission.id)
              expect(job_tracking.job_class).to eq(email_klass.class_name)
            end
          end

          it 'does not send an 4142 error email when it is not a SimpleFormsApi form and flippers are off' do
            Flipper.disable(CentralMail::SubmitForm4142Job::POLLING_FLIPPER_KEY)
            Flipper.disable(CentralMail::SubmitForm4142Job::POLLED_FAILURE_EMAIL)

            with_settings(Settings.vanotify.services.benefits_disability, { api_key: 'test_service_api_key' }) do
              expect do
                form_submission_attempt.fail!
                email_klass.drain
              end.to not_trigger_statsd_increment("#{email_klass::STATSD_METRIC_PREFIX}.success")
                .and not_change(Form526JobStatus, :count)
            end
          end
        end
      end
    end

    it 'transitions to a success state' do
      form_submission_attempt = create(:form_submission_attempt)

      expect(form_submission_attempt)
        .to transition_from(:pending).to(:success).on_event(:succeed)
    end

    context 'transitioning to a vbms state' do
      let(:notification_type) { :received }

      it 'transitions to a vbms state' do
        form_submission_attempt = create(:form_submission_attempt)

        expect(form_submission_attempt)
          .to transition_from(:pending).to(:vbms).on_event(:vbms)
      end

      it 'sends a received email' do
        notification_email = double
        allow(notification_email).to receive(:send)
        allow(SimpleFormsApi::NotificationEmail).to receive(:new).with(
          config,
          notification_type:,
          user_account: anything
        ).and_return(notification_email)
        form_submission_attempt = create(:form_submission_attempt)

        form_submission_attempt.vbms!

        expect(notification_email).to have_received(:send)
      end

      context 'form_data is nil' do
        let(:config) do
          {
            form_data: nil,
            form_number: anything,
            date_submitted: anything,
            lighthouse_updated_at: anything,
            confirmation_number: anything
          }
        end

        it 'gracefully handles the nil form_data' do
          notification_email = double
          allow(JSON).to receive(:parse)
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).with(
            config,
            notification_type:,
            user_account: anything
          ).and_return(notification_email)
          allow(notification_email).to receive(:send)
          form_submission_attempt = create(:form_submission_attempt)

          form_submission_attempt.vbms!

          expect(JSON).to have_received(:parse).with('{}')
        end
      end
    end
  end

  describe '#log_status_change' do
    it 'writes to Rails.logger.info' do
      logger = double
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      form_submission_attempt = create(:form_submission_attempt)

      form_submission_attempt.log_status_change

      expect(logger).to have_received(:info)
    end
  end
end
