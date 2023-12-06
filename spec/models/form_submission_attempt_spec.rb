# frozen_string_literal: true

require 'rails_helper'

# [wipn8923]
RSpec.describe FormSubmissionAttempt, type: :model do
  let(:user_account) { create(:user_account) }
  let(:saved_claim) { FactoryBot.build(:burial_claim) } # doesn't matter what type for spec
  let(:form_submission) { create(:form_submission, saved_claim:, user_account:) }
  let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

  describe 'associations' do
    it { should belong_to(:form_submission) }
  end

  describe 'validations' do
    # N/A
  end

  describe 'state machine' do
    it 'transitions to a failure state' do
      expect(form_submission_attempt)
        .to transition_from(:pending).to(:failure).on_event(:fail)
    end

    it 'transitions to a success state' do
      expect(form_submission_attempt)
        .to transition_from(:pending).to(:success).on_event(:succeed)
    end

    it 'transitions to a vbms state' do
      expect(form_submission_attempt)
        .to transition_from(:pending).to(:vbms).on_event(:vbms)
    end
  end

  describe 'methods' do
    context 'class' do
      # N/A
    end

    context 'instance' do
      describe '#log_status_change' do
        it 'writes to Rails.logger.info' do
        end
      end
      # N/A
    end
  end
end
