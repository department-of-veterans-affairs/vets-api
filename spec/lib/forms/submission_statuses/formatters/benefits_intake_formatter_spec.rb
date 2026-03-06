# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/dataset'
require 'forms/submission_statuses/formatters/benefits_intake_formatter'

describe Forms::SubmissionStatuses::Formatters::BenefitsIntakeFormatter,
         feature: :form_submission,
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

    context 'when form supports pdf download' do
      let(:mock_url) { 'https://s3.example.com/presigned-url' }

      before do
        allow_any_instance_of(Forms::SubmissionStatuses::PdfUrls)
          .to receive(:supported?).and_return(true)
        allow_any_instance_of(Forms::SubmissionStatuses::PdfUrls)
          .to receive(:fetch_url).and_return(mock_url)
      end

      it 'includes a presigned_url in the result' do
        dataset = instance_double(
          Forms::SubmissionStatuses::Dataset,
          submissions?: true,
          submissions:,
          intake_statuses?: false,
          intake_statuses: nil
        )

        result = subject.format_data(dataset)
        expect(result.first.presigned_url).to eq(mock_url)
        expect(result.first.pdf_support).to be(true)
      end
    end

    context 'when form does not support pdf download' do
      let(:unsupported_submissions) do
        [
          OpenStruct.new(
            id: 2,
            form_type: '999-unsupported',
            benefits_intake_uuid: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            user_account_id: '43134f0c-a772-4afa-857a-e5dedf8ea65a'
          )
        ]
      end

      it 'sets presigned_url to nil and pdf_support to false' do
        dataset = instance_double(
          Forms::SubmissionStatuses::Dataset,
          submissions?: true,
          submissions: unsupported_submissions,
          intake_statuses?: false,
          intake_statuses: nil
        )

        result = subject.format_data(dataset)
        expect(result.first.presigned_url).to be_nil
        expect(result.first.pdf_support).to be(false)
      end
    end

    context 'when fetching the presigned url raises an error' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::PdfUrls)
          .to receive(:supported?).and_return(true)
        allow_any_instance_of(Forms::SubmissionStatuses::PdfUrls)
          .to receive(:fetch_url).and_raise(StandardError, 'S3 connection failed')
      end

      it 'returns nil for presigned_url without raising' do
        dataset = instance_double(
          Forms::SubmissionStatuses::Dataset,
          submissions?: true,
          submissions:,
          intake_statuses?: false,
          intake_statuses: nil
        )

        expect(Rails.logger).to receive(:warn).with(
          'Failed to fetch presigned URL for submission in Forms::SubmissionStatuses',
          hash_including(submission_guid: '4b846069-e496-4f83-8587-42b570f24483', error: 'S3 connection failed')
        )

        result = subject.format_data(dataset)
        expect(result.first.presigned_url).to be_nil
        expect(result.first.pdf_support).to be(true)
      end
    end
  end
end
