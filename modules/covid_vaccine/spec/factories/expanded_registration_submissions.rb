# frozen_string_literal: true

FactoryBot.define do
  factory :covid_vax_expanded_registration, class: 'CovidVaccine::V0::ExpandedRegistrationSubmission' do
    submission_uuid { SecureRandom.uuid }
    state { 'sequestered' }
    vetext_sid { nil }

    # TODO: Update
    form_data {
      {
        vaccine_interest: 'INTERESTED',
        zip_code: '97212',
        time_at_zip: 'YES',
        phone: '808-555-1212',
        email: 'vets.gov.user+0@gmail.com',
        first_name: 'Jon',
        last_name: 'Doe',
        date_of_birth: '1900-01-01',
        patient_ssn: '666123456',
        patient_icn: '123456V123456',
        sta3n: '648',
        sta6a: '648GI'
      }
    }

    raw_form_data {
      {
        'vaccine_interest' => 'INTERESTED',
        'gender' => 'M',
        'zip_code' => '20420',
        'zip_code_details' => 'YES',
        'phone' => '808-555-1212',
        'email' => 'vets.gov.user+0@gmail.com',
        'first_name' => 'Jon',
        'last_name' => 'Doe',
        'birth_date' => '1900-01-01',
        'ssn' => '666512345',
        'country' => 'United States',
        'preferred_facility' => '123',
        'address_line1' => '810 Vermont Avenue',
        'city' => 'Washington',
        'state' => 'District of Columbia'
      }
    }

    trait :non_us do
      raw_form_data {
        {
          'vaccine_interest' => 'INTERESTED',
          'gender' => 'F',
          'zip_code' => '1000',
          'zip_code_details' => 'YES',
          'phone' => '808-555-1212',
          'email' => 'vets.gov.user+0@gmail.com',
          'first_name' => 'Jane',
          'last_name' => 'Doe',
          'birth_date' => '1900-01-01',
          'ssn' => '666512345',
          'country' => 'Philippines',
          'preferred_facility' => '123',
          'address_line1' => '1201 Roxas Blvd',
          'city' => 'Manila',
          'state' => 'Ermita'
        }
      }
    end
  end
end
