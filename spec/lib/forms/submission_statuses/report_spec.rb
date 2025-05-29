# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateway'
require 'forms/submission_statuses/report'

describe Forms::SubmissionStatuses::Report, feature: :form_submission,
                                            team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new(user_account:, allowed_forms:) }

  let(:user_account) { create(:user_account) }
  let(:allowed_forms) { %w[20-10207 21-0845 21-0972 21-10210 21-4142 21-4142a 21P-0847] }

  context 'when user has no submissions' do
    before do
      allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:submissions).and_return([])
      allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return([nil, nil])
    end

    it 'returns an empty array' do
      result = subject.run
      expect(result.status_submissions).to be_nil
    end
  end

  context 'when user has submissions' do
    before do
      create(:form_submission, :with_form214142, user_account_id: user_account.id)
      create(:form_submission, :with_form210845, user_account_id: user_account.id)

      # This form is not in the allowed forms list and should not be included
      create(:form_submission, :with_form_blocked, user_account_id: user_account.id)

      # This 20-10207 form is older than 60 days and should not be included in the results
      create(:form_submission, :with_form2010207, user_account_id: user_account.id)
    end

    context 'has statuses' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => '4b846069-e496-4f83-8587-42b570f24483',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => '4b846069-e496-4f83-8587-42b570f24483',
                  'message' => 'message',
                  'status' => 'received',
                  'updated_at' => 2.days.ago
                }
              },
              {
                'id' => 'd0c6cea6-9885-4e2f-8e0c-708d5933833a',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => 'd0c6cea6-9885-4e2f-8e0c-708d5933833a',
                  'message' => 'message',
                  'status' => 'received',
                  'updated_at' => 3.days.ago
                }
              }
            ],
            nil
          ]
        )
      end

      it 'returns the correct count' do
        result = subject.run

        expect(result.submission_statuses.size).to be(2)
        expect(result.errors).to be_nil
      end

      it 'sorts results' do
        result = subject.run

        submission_statuses = result.submission_statuses
        expect(submission_statuses.first.updated_at).to be <= submission_statuses.last.updated_at
      end

      it 'returns the correct values' do
        result = subject.run

        submission_status = result.submission_statuses.first
        expect(submission_status.id).to eq('d0c6cea6-9885-4e2f-8e0c-708d5933833a')
        expect(submission_status.detail).to eq('detail')
        expect(submission_status.form_type).to eq('21-0845')
        expect(submission_status.message).to eq('message')
        expect(submission_status.status).to eq('received')
        expect(submission_status.pdf_support).to be(true)
      end
    end

    context 'when no statuses' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return([nil, nil])
      end

      it 'returns the correct count' do
        result = subject.run

        expect(result.submission_statuses.size).to be(2)
      end

      it 'returns the correct values' do
        result = subject.run

        submission_status = result.submission_statuses.first
        expect(submission_status.id).to eq('4b846069-e496-4f83-8587-42b570f24483')
        expect(submission_status.detail).to be_nil
        expect(submission_status.form_type).to eq('21-4142')
        expect(submission_status.message).to be_nil
        expect(submission_status.status).to be_nil
        expect(submission_status.pdf_support).to be(true)
      end
    end

    context 'when missing status' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => '4b846069-e496-4f83-8587-42b570f24483',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => '4b846069-e496-4f83-8587-42b570f24483',
                  'message' => 'message',
                  'updated_at' => 2.days.ago,
                  'status' => 'received'
                }
              }
            ]
          ],
          nil
        )
      end

      it 'returns the correct count' do
        result = subject.run

        expect(result.submission_statuses.size).to be(2)
      end

      it 'sorts results' do
        result = subject.run

        expect(result.submission_statuses.first.updated_at).to be_nil
        expect(result.submission_statuses.last.updated_at).not_to be_nil
      end
    end
  end
end
