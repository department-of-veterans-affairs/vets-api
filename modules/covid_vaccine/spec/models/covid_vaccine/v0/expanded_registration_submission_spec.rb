# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::V0::ExpandedRegistrationSubmission, type: :model do
  describe '#to_csv' do
    before do
      FactoryBot.create_list(:covid_vax_expanded_registration, 3, state: 'sequestered')
      FactoryBot.create_list(:covid_vax_expanded_registration, 1, state: 'eligible_us')
      FactoryBot.create_list(:covid_vax_expanded_registration, 2, :non_us, state: 'eligible_non_us')
    end

    it 'generates CSV of eligible submissions residing in United States ordered by created_at DESC' do
      expect(described_class.to_csv).to eq(
        'Jon^^Doe^1900-01-01^666512345^M^^810 Vermont Avenue^Washington^District of Columbia^20420^808-555-1212^'\
        "vets.gov.user+0@gmail.com^123^8\n"
      )
    end
  end
end
