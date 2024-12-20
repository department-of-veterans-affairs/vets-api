# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/dataset'
require 'forms/submission_statuses/formatter'

describe Forms::SubmissionStatuses::Formatter, feature: :form_submission,
                                               team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new }

  context 'when no submission data' do
    it 'returns empty array' do
      dataset = double
      allow(dataset).to receive(:submissions?).and_return(false)
      expect(subject.format_data(dataset)).to be_empty
    end
  end

  context 'when submission data' do
    let(:submissions) do
      [
        OpenStruct.new(
          id: 1,
          form_type: '21-0966',
          benefits_intake_uuid: '4b846069-e496-4f83-8587-42b570f24483',
          user_account_id: '43134f0c-a772-4afa-857a-e5dedf8ea65a'
        )
      ]
    end

    it 'returns data' do
      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions:,
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = subject.format_data(dataset)
      expect(result).not_to be_empty
    end
  end
end
