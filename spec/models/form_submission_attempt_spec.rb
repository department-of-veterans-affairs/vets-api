# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormSubmissionAttempt, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:form_submission) }
  end

  describe 'state machine' do
    it 'transitions to a failure state' do
      form_submission_attempt = create(:form_submission_attempt)

      expect(form_submission_attempt)
        .to transition_from(:pending).to(:failure).on_event(:fail)
    end

    it 'transitions to a success state' do
      form_submission_attempt = create(:form_submission_attempt)

      expect(form_submission_attempt)
        .to transition_from(:pending).to(:success).on_event(:succeed)
    end

    it 'transitions to a vbms state' do
      form_submission_attempt = create(:form_submission_attempt)

      expect(form_submission_attempt)
        .to transition_from(:pending).to(:vbms).on_event(:vbms)
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
