# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/dataset'
require 'forms/submission_statuses/formatters/ivc_champva_formatter'

RSpec.describe Forms::SubmissionStatuses::Formatters::IvcChampvaFormatter do
  subject(:formatter) { described_class.new }

  describe '#format_data' do
    it 'maps CHAMPVA statuses into submission status payload shape' do
      dataset = Forms::SubmissionStatuses::Dataset.new
      dataset.submissions = [
        OpenStruct.new(
          id: 'guid-123',
          form_type: '10-10D',
          created_at: Time.zone.parse('2026-02-05T13:00:00Z'),
          updated_at: Time.zone.parse('2026-02-05T15:00:00Z')
        )
      ]
      dataset.intake_statuses = [
        {
          'attributes' => {
            'guid' => 'guid-123',
            'status' => 'pending',
            'message' => 'Form submitted',
            'detail' => 'Pending',
            'updated_at' => Time.zone.parse('2026-02-05T15:00:00Z')
          }
        }
      ]

      result = formatter.format_data(dataset)

      expect(result.size).to eq(1)
      expect(result.first.id).to eq('guid-123')
      expect(result.first.form_type).to eq('10-10D')
      expect(result.first.status).to eq('pending')
      expect(result.first.message).to eq('Form submitted')
      expect(result.first.detail).to eq('Pending')
      expect(result.first.pdf_support).to be(false)
    end
  end
end
