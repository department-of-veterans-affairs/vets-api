# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Profile::Serializer do
  let(:info) do
    { FirstName: 'Aminul',
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
      PersonalEmail: 'aminul.islam@va.gov',
      BusinessEmail: 'test@va.gov',
      SchoolState: nil,
      SchoolFacilityCode: nil,
      ServiceNumber: nil,
      ClaimNumber: nil,
      VeteranServiceStartDate: '1/1/0001 12:00:00 AM',
      VeteranServiceEndDate: '1/1/0001 12:00:00 AM',
      DateOfBirth: '7/22/1991 12:00:00 AM',
      EDIPI: nil,
      icn: '123456' }
  end
  let(:profile) { AskVAApi::Profile::Entity.new(info) }
  let(:response) { described_class.new(profile) }
  let(:expected_response) do
    { data: { id: info[:icn],
              type: :profile,
              attributes: { first_name: info[:FirstName],
                            middle_name: info[:MiddleName],
                            last_name: info[:LastName],
                            preferred_name: info[:PreferredName],
                            suffix: info[:Suffix],
                            gender: info[:Gender],
                            pronouns: info[:Pronouns],
                            country: info[:Country],
                            street: info[:Street],
                            city: info[:City],
                            state: info[:State],
                            zip_code: info[:ZipCode],
                            province: info[:Province],
                            business_phone: info[:BusinessPhone],
                            personal_phone: info[:PersonalPhone],
                            personal_email: info[:PersonalEmail],
                            business_email: info[:BusinessEmail],
                            school_state: info[:SchoolState],
                            school_facility_code: info[:SchoolFacilityCode],
                            service_number: info[:ServiceNumber],
                            claim_number: info[:ClaimNumber],
                            veteran_service_start_date: info[:VeteranServiceStartDate],
                            veteran_service_end_date: info[:VeteranServiceEndDate],
                            date_of_birth: info[:DateOfBirth],
                            edipi: info[:EDIPI] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
