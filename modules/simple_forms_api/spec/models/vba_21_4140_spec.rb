# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA214140 do
  subject(:form) { described_class.new(data) }

  let(:data) do
    {
      form_number: '21-4140',
      veteran: {
        address: { postal_code: 12_345 },
        full_name: { first: 'John', last: 'Doe' },
        va_file_number: 12_345
      }
    }
  end

  describe '#data' do
    subject { form.data }

    it { is_expected.to match(data) }
  end

  describe '#metadata' do
    subject { form.metadata }

    it 'returns the proper hash' do
      expect(subject).to match(
        {
          'veteranFirstName' => data.dig('veteran', 'full_name', 'first'),
          'veteranLastName' => data.dig('veteran', 'full_name', 'last'),
          'fileNumber' => data.dig('veteran',
                                   'va_file_number'),
          'zipCode' => data.dig('veteran', 'address', 'postal_code'),
          'source' => 'VA Platform Digital Forms',
          'docType' => data['form_number'],
          'businessLine' => 'CMP'
        }
      )
    end
  end

  describe '#signature_date' do
    subject { form.signature_date }

    let(:date) { 45.days.ago }

    it 'returns the date the instance was created' do
      Timecop.freeze(date) do
        expect(subject).to eq(date)
      end
    end
  end
end
