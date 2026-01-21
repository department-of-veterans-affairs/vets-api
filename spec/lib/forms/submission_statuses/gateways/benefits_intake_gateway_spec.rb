# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateways/benefits_intake_gateway'

describe Forms::SubmissionStatuses::Gateways::BenefitsIntakeGateway,
         feature: :form_submission,
         team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new(user_account:, allowed_forms:) }

  let(:user_account) { create(:user_account) }
  let(:allowed_forms) { %w[21-0845 21-4142] }

  describe '#data' do
    it 'returns a dataset with submissions and intake statuses' do
      # Mock the submissions query to return empty array
      allow(SecondaryAppealForm).to receive(:joins).and_return(double(where: double(where: [])))

      result = subject.data

      expect(result).to be_a(Forms::SubmissionStatuses::Dataset)
    end
  end

  describe '#submissions' do
    context 'with allowed forms' do
      before do
        create(:form_submission, :with_form214142, user_account_id: user_account.id)
        create(:form_submission, :with_form210845, user_account_id: user_account.id)
        create(:form_submission, :with_form_blocked, user_account_id: user_account.id)
      end

      it 'returns only submissions for allowed forms' do
        submissions = subject.submissions
        expect(submissions.size).to eq(2)
        expect(submissions.map(&:form_type)).to contain_exactly('21-4142', '21-0845')
      end
    end

    context 'without allowed forms restriction' do
      let(:allowed_forms) { nil }

      before do
        create(:form_submission, :with_form214142, user_account_id: user_account.id)
        create(:form_submission, :with_form210845, user_account_id: user_account.id)
        create(:form_submission, :with_form_blocked, user_account_id: user_account.id)
      end

      it 'returns all submissions for the user' do
        submissions = subject.submissions
        expect(submissions.size).to eq(3)
      end
    end
  end
end
