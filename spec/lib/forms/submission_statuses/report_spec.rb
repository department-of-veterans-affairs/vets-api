# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateway'
require 'forms/submission_statuses/report'

describe Forms::SubmissionStatuses::Report do
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
      create(:form_submission, :with_form_blocked, user_account_id: user_account.id)
    end

    context 'has statuses' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => 'eff61cbc-f379-421d-977e-d7fd1a06bca3',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => 'eff61cbc-f379-421d-977e-d7fd1a06bca3',
                  'message' => 'message',
                  'status' => 'received',
                  'updated_at' => '2024-03-13T18:51:00.953Z'
                }
              },
              {
                'id' => '6d353dee-a0e0-40e3-a25c-9b652247a0d9',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => '6d353dee-a0e0-40e3-a25c-9b652247a0d9',
                  'message' => 'message',
                  'status' => 'received',
                  'updated_at' => '2024-03-08T19:30:39.939Z'
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
        expect(submission_status.id).to eq('6d353dee-a0e0-40e3-a25c-9b652247a0d9')
        expect(submission_status.detail).to eq('detail')
        expect(submission_status.form_type).to eq('21-0845')
        expect(submission_status.message).to eq('message')
        expect(submission_status.status).to eq('received')
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
        expect(submission_status.id).to eq('eff61cbc-f379-421d-977e-d7fd1a06bca3')
        expect(submission_status.detail).to be_nil
        expect(submission_status.form_type).to eq('21-4142')
        expect(submission_status.message).to be_nil
        expect(submission_status.status).to be_nil
      end
    end

    context 'when missing status' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => 'eff61cbc-f379-421d-977e-d7fd1a06bca3',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => 'eff61cbc-f379-421d-977e-d7fd1a06bca3',
                  'message' => 'message',
                  'updated_at' => '2024-03-13T18:51:00.953Z',
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
