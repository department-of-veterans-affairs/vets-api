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
        'Jon^^Doe^01/01/1900^666112222^M^^810 Vermont Avenue^Washington^DC^20420^(808)5551212^'\
        "vets.gov.user+0@gmail.com^vha_684^8\n"
      )
    end
  end
end
