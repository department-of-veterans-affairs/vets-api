# frozen_string_literal: true

# Since most of the interesting attributes are nested in the raw_form_data hash,
# this factory merges in default_options (to be overriden in traits and child factories)
# and options (to be overriden in individual specs) so that you can override individual fields within
# raw_form_data
FactoryBot.define do
  factory :covid_vax_expanded_registration, class: 'CovidVaccine::V0::ExpandedRegistrationSubmission' do
    submission_uuid { SecureRandom.uuid }
    state { 'received' }
    vetext_sid { nil }
    transient do
      base_raw_data {
        {
          'first_name' => 'Jon',
          'middle_name' => nil,
          'last_name' => 'Doe',
          'ssn' => '666112222',
          'birth_date' => '1900-01-01',
          'birth_sex' => 'Male',
          'applicant_type' => 'veteran',
          'last_branch_of_service' => 'Navy',
          'character_of_service' => 'Honorable',
          'date_range' => { 'from' => '1980-03-XX', 'to' => '1984-01-XX' },
          'preferred_facility' => 'vha_684',
          'email_address' => 'vets.gov.user+0@gmail.com',
          'phone' => '808-555-1212',
          'sms_acknowledgement' => true,
          'address_line1' => '810 Vermont Avenue',
          'address_line2' => nil,
          'address_line3' => nil,
          'city' => 'Washington',
          'state_code' => 'DC',
          'zip_code' => '20420',
          'country_name' => 'USA',
          'compliance_agreement' => true,
          'privacy_agreement_accepted' => true
        }
      }

      default_raw_options { {} }
      raw_options { {} }
    end

    raw_form_data { base_raw_data.merge(default_raw_options).merge(raw_options) }

    # TODO: Derive this from raw_form_data? Or at least make it match
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

    trait :non_us do
      default_raw_options {
        {
          'preferred_facility' => 'vha_358',
          'address_line1' => '1201 Roxas Blvd',
          'city' => 'Manila',
          'state_code' => 'Ermita',
          'zip_code' => '1000',
          'country_name' => 'Philippines'
        }
      }
    end

    trait :canada do
      default_raw_options {
        {
          'preferred_facility' => 'vha_358',
          'address_line1' => '6393 NW Marine Dr',
          'city' => 'Vancouver',
          'state_code' => 'BC',
          'zip_code' => 'V6T 1Z2',
          'country_name' => 'Canada'
        }
      }
    end

    trait :mexico do
      default_raw_options {
        {
          'preferred_facility' => 'vha_358',
          'address_line1' => 'Calz Independencia 998',
          'address_line2' => 'Centro Cívico',
          'city' => 'Mexicali',
          'state_code' => 'BC',
          'zip_code' => '21000',
          'country_name' => 'Mexico'
        }
      }
    end

    trait :spouse do
      default_raw_options {
        {
          'applicant_type' => 'spouse',
          'veteran_ssn' => '666001111',
          'veteran_birth_date' => '1950-05-05',
          'last_branch_of_service' => nil,
          'character_of_service' => nil,
          'date_range' => nil
        }
      }
    end

    trait :blank_email do
      default_raw_options {
        {
          'email_address' => nil
        }
      }
    end
  end
end
