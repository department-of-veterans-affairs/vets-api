# frozen_string_literal: true

require 'rails_helper'
require 'covid_vaccine/v0/expanded_registration_csv_generator'

describe CovidVaccine::V0::ExpandedRegistrationCsvGenerator do
  subject do
    fixture_file = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    records = fixture_file.values.map do |fixture|
      build(:covid_vax_expanded_registration, raw_form_data: fixture['raw_form_data'])
    end
    described_class.new(records)
  end

  describe '#csv' do
    it 'generates CSV string based on records provided' do
      expect(subject.csv).to be_a(String)
      expect(subject.csv).to eq(
        File.read('modules/covid_vaccine/spec/fixtures/csv_string.txt')
      )
    end

    it 'uses mapped facility info if present' do
      record = build(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'Portland VA Medical Center' },
                     eligibility_info: { 'preferred_facility' => '648' })
      generator = described_class.new([record])
      expect(generator.csv).to include('^648^')
    end

    it 'uses mapped info if recorded but nil' do
      record = build(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'Some Fake Facility' },
                     eligibility_info: { 'preferred_facility' => nil })
      generator = described_class.new([record])
      expect(generator.csv).not_to include('^Some Fake Facility^')
    end

    it 'uses submitted facility info if mapping not needed' do
      record = build(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'vha_688' },
                     eligibility_info: nil)
      generator = described_class.new([record])
      expect(generator.csv).to include('^688^')
    end

    describe 'birth sex field' do
      it 'maps Male value to M' do
        record = build(:covid_vax_expanded_registration, raw_options: { 'ssn' => '123456789', 'birth_sex' => 'Male' })
        generator = described_class.new([record])
        expect(generator.csv).to include('^123456789^M^')
      end

      it 'maps Female value to F' do
        record = build(:covid_vax_expanded_registration, raw_options: { 'ssn' => '123456789', 'birth_sex' => 'Female' })
        generator = described_class.new([record])
        expect(generator.csv).to include('^123456789^F^')
      end

      it 'maps Prefer not to state value to nil' do
        record = build(:covid_vax_expanded_registration,
                       raw_options: { 'ssn' => '123456789', 'birth_sex' => 'Prefer not to state' })
        generator = described_class.new([record])
        expect(generator.csv).to include('^123456789^^')
        expect(generator.csv).not_to include('^P^')
      end

      it 'maps nil value to nil' do
        record = build(:covid_vax_expanded_registration, raw_options: { 'ssn' => '123456789', 'birth_sex' => nil })
        generator = described_class.new([record])
        expect(generator.csv).to include('^123456789^^')
      end
    end
  end

  describe '#io' do
    it 'generates IO String suitable for SFTP' do
      expect(subject.io).to be_a(StringIO)
      expect(subject.io.size).to eq(1497)
    end
  end
end
