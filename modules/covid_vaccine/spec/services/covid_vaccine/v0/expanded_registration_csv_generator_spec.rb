# frozen_string_literal: true

require 'rails_helper'
require 'covid_vaccine/v0/expanded_registration_csv_generator'

describe CovidVaccine::V0::ExpandedRegistrationCsvGenerator do
  subject do
    fixture_file = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions.yml')
    records = fixture_file.values.map do |fixture|
      FactoryBot.build(:covid_vax_expanded_registration, raw_form_data: fixture['raw_form_data'])
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
  end

  describe '#io' do
    it 'generates IO String suitable for SFTP' do
      expect(subject.io).to be_a(StringIO)
      expect(subject.io.size).to eq(1497)
    end
  end
end
