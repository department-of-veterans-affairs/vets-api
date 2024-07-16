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
      allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:statuses).and_return(nil)
    end

    it 'returns an empty array' do
      results = subject.run
      expect(results).to be_empty
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
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:statuses).and_return(
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
          ]
        )
      end

      it 'returns the correct count' do
        results = subject.run

        expect(results.size).to be(2)
      end

      it 'sorts results' do
        results = subject.run

        expect(results.first.created_at).to be('2024-03-08')
        expect(results.last.created_at).to be('2024-03-12')
      end

      it 'returns the correct values' do
        results = subject.run

        expect(results.first.id).to be('d0c6cea6')
        expect(results.first.detail).to be('detail')
        expect(results.first.form_type).to be('21-0966')
        expect(results.first.message).to be('message')
        expect(results.first.status).to be('received')
        expect(results.first.created_at).to be('2024-03-08')
        expect(results.first.updated_at).to be('2024-03-08T19:30:39.939Z')
      end
    end

    context 'when no statuses' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:statuses).and_return(nil)
      end

      it 'returns the correct count' do
        results = subject.run

        expect(results.size).to be(2)
      end

      it 'returns the correct values' do
        results = subject.run

        expect(results.first.id).to be('4b846069')
        expect(results.first.detail).to be_nil
        expect(results.first.form_type).to be('21-4142')
        expect(results.first.message).to be_nil
        expect(results.first.status).to be_nil
        expect(results.first.created_at).to be('2024-03-12')
        expect(results.first.updated_at).to be_nil
      end
    end

    context 'when missing status' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:statuses).and_return(
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
        )
      end

      it 'returns the correct count' do
        results = subject.run

        expect(results.size).to be(2)
      end

      it 'sorts results' do
        results = subject.run

        expect(results.first.updated_at).to be_nil
        expect(results.last.updated_at).not_to be_nil
      end
    end
  end
end
