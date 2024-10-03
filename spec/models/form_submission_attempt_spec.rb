# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormSubmissionAttempt, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:form_submission) }
  end

  describe 'state machine' do
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

      it 'sends an error email' do
        notification_email = double
        allow(notification_email).to receive(:send)
        allow(SimpleFormsApi::NotificationEmail).to receive(:new).with(
          config,
          notification_type:,
          user_account: anything
        ).and_return(notification_email)
        form_submission_attempt = create(:form_submission_attempt)

        form_submission_attempt.fail!

        expect(notification_email).to have_received(:send)
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
