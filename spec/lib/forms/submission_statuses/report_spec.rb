# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateway'
require 'forms/submission_statuses/report'

describe Forms::SubmissionStatuses::Report do
  subject { described_class.new(user_account) }

  let(:user_account) { OpenStruct.new(user_account_id:) }
  let(:user_account_id) { '43134f0c' }

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
      allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:submissions).and_return(
        [
          OpenStruct.new(
            id: 1,
            form_type: '21-4142',
            benefits_intake_uuid: '4b846069',
            user_account_id:,
            created_at: '2024-03-12'
          ),
          OpenStruct.new(
            id: 2,
            form_type: '21-0966',
            benefits_intake_uuid: 'd0c6cea6',
            user_account_id:,
            created_at: '2024-03-08'
          )
        ]
      )
    end

    context 'has statuses' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => '4b846069',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => '4b846069',
                  'message' => 'message',
                  'status' => 'received',
                  'updated_at' => '2024-03-13T18:51:00.953Z'
                }
              },
              {
                'id' => 'd0c6cea6',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => 'd0c6cea6',
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
        expect(submission_statuses.first.created_at).to be('2024-03-08')
        expect(submission_statuses.last.created_at).to be('2024-03-12')
      end

      it 'returns the correct values' do
        result = subject.run

        submission_status = result.submission_statuses.first
        expect(submission_status.id).to be('d0c6cea6')
        expect(submission_status.detail).to be('detail')
        expect(submission_status.form_type).to be('21-0966')
        expect(submission_status.message).to be('message')
        expect(submission_status.status).to be('received')
        expect(submission_status.created_at).to be('2024-03-08')
        expect(submission_status.updated_at).to be('2024-03-08T19:30:39.939Z')
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
        expect(submission_status.id).to be('4b846069')
        expect(submission_status.detail).to be_nil
        expect(submission_status.form_type).to be('21-4142')
        expect(submission_status.message).to be_nil
        expect(submission_status.status).to be_nil
        expect(submission_status.created_at).to be('2024-03-12')
        expect(submission_status.updated_at).to be_nil
      end
    end

    context 'when missing status' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:intake_statuses).and_return(
          [
            [
              {
                'id' => '4b846069',
                'attributes' => {
                  'detail' => 'detail',
                  'guid' => '4b846069',
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
