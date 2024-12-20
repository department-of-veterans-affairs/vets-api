# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA214140 do
  subject(:form) { described_class.new(data) }

  let(:fixture_file) { 'vba_21_4140.json' }
  let(:fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', fixture_file)
  end
  let(:data) { JSON.parse(fixture_path.read) }

  it_behaves_like 'zip_code_is_us_based', %w[address]

  shared_examples 'hyphenated_phone_number' do
    it { is_expected.to match(/\d{3}-\d{3}-\d{4}/) }
  end

  describe '#data' do
    subject { form.data }

    it { is_expected.to match(data) }
  end

  describe '#dob' do
    subject(:dob) { form.dob }

    let(:year) { dob[0] }
    let(:month) { dob[1] }
    let(:day) { dob[2] }

    context 'when dob exists' do
      it 'returns an array of numbers' do
        expect(year).to eq data['date_of_birth'][0..3]
        expect(month).to eq data['date_of_birth'][5..6]
        expect(day).to eq data['date_of_birth'][8..9]
      end
    end

    context 'when dob is missing' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it 'returns an array with empty values' do
        expect(year).to eq nil
        expect(month).to eq nil
        expect(day).to eq nil
      end
    end
  end

  describe '#first_name' do
    subject { form.first_name }

    it('is limited to twelve characters') do
      expect(data.dig('full_name', 'first').length).to be > 12
      expect(subject.length).to eq 12
    end
  end

  describe '#last_name' do
    subject { form.last_name }

    it('is limited to eighteen characters') do
      expect(data.dig('full_name', 'last').length).to be > 18
      expect(subject.length).to eq 18
    end
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

  describe '#middle_initial' do
    subject { form.middle_initial }

    it 'is limited to one character' do
      expect(data.dig('full_name', 'middle').length).to be > 1
      expect(subject.length).to eq 1
    end
  end

  describe '#phone_alternate' do
    subject { form.phone_alternate }

    it_behaves_like 'hyphenated_phone_number'
  end

  describe '#phone_primary' do
    subject { form.phone_primary }

    it_behaves_like 'hyphenated_phone_number'
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

  describe '#ssn' do
    subject(:ssn) { form.ssn }

    let(:first_three) { ssn[0] }
    let(:second_two) { ssn[1] }
    let(:last_four) { ssn[2] }

    context 'when ssn exists' do
      it 'returns an array of numbers' do
        expect(first_three.length).to eq 3
        expect(second_two.length).to eq 2
        expect(last_four.length).to eq 4
      end
    end

    context 'when ssn is missing' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it 'returns an array with empty values' do
        expect(first_three).to eq nil
        expect(second_two).to eq nil
        expect(last_four).to eq nil
      end
    end
  end
end
