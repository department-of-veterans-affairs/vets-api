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

  describe '#address' do
    subject(:address) { form.address }

    it { is_expected.to be_a FormEngine::Address }

    it 'maps correctly to attributes' do
      expect(address.address_line1).to eq data.dig('address', 'street')
      expect(address.address_line2).to eq data.dig('address', 'street2')
      expect(address.city).to eq data.dig('address', 'city')
      expect(address.state_code).to eq data.dig('address', 'state')
      expect(address.zip_code).to eq data.dig('address', 'postal_code')
      expect(address.country_code_iso3).to eq data.dig('address', 'country')
      expect(address.country_code_iso2).to eq IsoCountryCodes.find(data.dig('address', 'country')).alpha2
    end
  end

  describe '#data' do
    subject { form.data }

    it { is_expected.to match(data) }
  end

  describe '#desired_stamps' do
    subject(:desired_stamps) { form.desired_stamps }

    it 'only adds one stamp' do
      expect(desired_stamps.size).to eq 1
    end

    it 'contains the correct properties' do
      expect(desired_stamps[0][:text]).to eq form.signature_employed
      expect(desired_stamps[0][:page]).to eq 1
    end
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
        expect(year).to be_nil
        expect(month).to be_nil
        expect(day).to be_nil
      end
    end
  end

  describe '#employed?' do
    subject { form.employed? }

    context 'when employers exist' do
      it { is_expected.to be true }
    end

    context 'when employers do not exist' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it { is_expected.to be false }
    end
  end

  describe '#employment_history' do
    subject(:employment_history) { form.employment_history }

    it 'returns an array of four EmploymentHistory instances' do
      expect(employment_history.length).to eq 4
      expect(employment_history[0]).to be_a FormEngine::EmploymentHistory
      expect(employment_history[0].lost_time).to eq data['employers'][0]['lost_time']
      expect(employment_history[3]).to be_a FormEngine::EmploymentHistory
      expect(employment_history[3].lost_time).to be_nil
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

  describe '#signature_date_employed' do
    subject { form.signature_date_employed }

    context 'when employed' do
      it { is_expected.to match(%r{\d{2}/\d{2}/\d{4}}) }
    end

    context 'when unemployed' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it { is_expected.to be_nil }
    end
  end

  describe '#signature_date_unemployed' do
    subject { form.signature_date_unemployed }

    context 'when employed' do
      it { is_expected.to be_nil }
    end

    context 'when unemployed' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it { is_expected.to match(%r{\d{2}/\d{2}/\d{4}}) }
    end
  end

  describe '#signature_employed' do
    subject { form.signature_employed }

    context 'when employed' do
      it { is_expected.to eq data['statement_of_truth_signature'] }
    end

    context 'when unemployed' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it { is_expected.to be_nil }
    end
  end

  describe '#signature_unemployed' do
    subject { form.signature_unemployed }

    context 'when employed' do
      it { is_expected.to be_nil }
    end

    context 'when unemployed' do
      let(:fixture_file) { 'vba_21_4140-min.json' }

      it { is_expected.to eq data['statement_of_truth_signature'] }
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
        expect(first_three).to be_nil
        expect(second_two).to be_nil
        expect(last_four).to be_nil
      end
    end
  end
end
