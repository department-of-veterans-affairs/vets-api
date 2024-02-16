# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Profile::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      FirstName: 'Aminul',
      MiddleName: nil,
      LastName: nil,
      PreferredName: 'test',
      Suffix: 'Jr',
      Gender: 'Female',
      Pronouns: nil,
      Country: 'United States',
      Street: nil,
      City: nil,
      State: nil,
      ZipCode: nil,
      Province: nil,
      BusinessPhone: '(973)767-7598',
      PersonalPhone: nil,
      PersonalEmail: 'aminul.islamva.gov',
      BusinessEmail: 'testva.gov',
      SchoolState: nil,
      SchoolFacilityCode: nil,
      ServiceNumber: nil,
      ClaimNumber: nil,
      VeteranServiceStartDate: '1/1/0001 12:00:00 AM',
      VeteranServiceEndDate: '1/1/0001 12:00:00 AM',
      DatOfBirth: '7/22/1991 12:00:00 AM',
      EDIPI: nil
    }
  end
  let(:profile) { creator.new(info) }

  it 'creates an profile' do
    expect(profile).to have_attributes({
                                         business_email: info[:BusinessEmail],
                                         business_phone: info[:BusinessPhone],
                                         city: info[:City],
                                         claim_number: info[:ClaimNumber],
                                         country: info[:Country],
                                         date_of_birth: info[:DateofBirth],
                                         edipi: info[:EDIPI],
                                         first_name: info[:FirstName],
                                         gender: info[:Gender],
                                         last_name: info[:LastName],
                                         middle_name: info[:MiddleName],
                                         personal_email: info[:PersonalEmail],
                                         personal_phone: info[:PersonalPhone],
                                         preferred_name: info[:PreferredName],
                                         pronouns: info[:Pronous],
                                         province: info[:Province],
                                         school_facility_code: info[:SchoolFacilityCode],
                                         school_state: info[:SchoolState],
                                         service_number: info[:ServiceNumber],
                                         state: info[:State],
                                         street: info[:Street],
                                         suffix: info[:Suffix],
                                         veteran_service_end_date: info[:VeteranServiceEndDate],
                                         veteran_service_start_date: info[:VeteranServiceStartDate],
                                         zip_code: info[:ZipCode]
                                       })
  end
end
