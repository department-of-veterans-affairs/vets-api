# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA214140 do
  subject(:form) { described_class.new(data) }

  let(:fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_4140.json')
  end
  let(:data) { JSON.parse(fixture_path.read) }

  it_behaves_like 'zip_code_is_us_based', %w[address]

  describe '#data' do
    subject { form.data }

    it { is_expected.to match(data) }
  end

  describe '#metadata' do
    subject { form.metadata }

    it 'returns the proper hash' do
      expect(subject).to match(
        {
          'veteranFirstName' => data.dig('full_name', 'first'),
          'veteranLastName' => data.dig('full_name', 'last'),
          'fileNumber' => data['va_file_number'],
          'zipCode' => data.dig('address', 'postal_code'),
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
