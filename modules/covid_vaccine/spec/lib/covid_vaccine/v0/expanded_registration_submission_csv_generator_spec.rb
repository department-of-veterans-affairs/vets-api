# frozen_string_literal: true

require 'rails_helper'
require 'covid_vaccine/v0/expanded_registration_submission_csv_generator'

describe CovidVaccine::V0::ExpandedRegistrationSubmissionCSVGenerator do
  subject do
    described_class.new(CovidVaccine::V0::ExpandedRegistrationSubmission.eligible_us.order(:created_at))
  end

  before do
    FactoryBot.create_list(:covid_vax_expanded_registration, 1, state: 'eligible_us')
  end

  describe '#csv' do
    it 'generates CSV string based on records provided' do
      expect(subject.csv).to eq(
        'Jon^^Doe^01/01/1900^666112222^M^^810 Vermont Avenue^Washington^DC^20420^(808)5551212^'\
        "vets.gov.user+0@gmail.com^684^8\n"
      )
      expect(subject.csv).to be_a(String)
    end
  end

  describe '#io' do
    it 'generates IO String suitable for SFTP' do
      expect(subject.io.string).to eq(
        'Jon^^Doe^01/01/1900^666112222^M^^810 Vermont Avenue^Washington^DC^20420^(808)5551212^'\
        "vets.gov.user+0@gmail.com^684^8\n"
      )
      expect(subject.io.size).to eq(117)
      expect(subject.io).to be_a(StringIO)
    end
  end
end
