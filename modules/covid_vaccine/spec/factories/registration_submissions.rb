# frozen_string_literal: true

FactoryBot.define do
  factory :covid_vax_registration, class: 'CovidVaccine::V0::RegistrationSubmission' do
    sid { SecureRandom.uuid }
    account_id { SecureRandom.uuid }

    form_data {
      {
        vaccine_interest: 'INTERESTED',
        zip_code: '97212',
        time_at_zip: 'YES',
        phone: '808-555-1212',
        email: 'foo@example.com',
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
        'zip_code' => '97212',
        'zip_code_details' => 'YES',
        'phone' => '808-555-1212',
        'email' => 'foo@example.com',
        'first_name' => 'Jon',
        'last_name' => 'Doe',
        'birth_date' => '1900-01-01',
        'ssn' => '6665123456'
      }
    }
  end

  trait :unsubmitted do
    sid { nil }
    form_data { nil }
  end

  trait :anonymous do
    account_id { nil }
  end

  trait :lacking_pii_traits do
    raw_form_data {
      {
        'vaccine_interest' => 'INTERESTED',
        'zip_code' => '97212',
        'zip_code_details' => 'YES',
        'phone' => '808-555-1212',
        'email' => 'foo@example.com',
        'first_name' => 'Jon',
        'last_name' => 'Doe'
      }
    }
  end

  trait :invalid_dob do
    raw_form_data {
      {
        'vaccine_interest' => 'INTERESTED',
        'zip_code' => '97212',
        'zip_code_details' => 'YES',
        'phone' => '808-555-1212',
        'email' => 'foo@example.com',
        'first_name' => 'Jon',
        'last_name' => 'Doe',
        'birth_date' => '1900-01-XX',
        'ssn' => '6665123456'
      }
    }
  end

  trait :from_loa3 do
    raw_form_data {
      {
        'vaccine_interest' => 'INTERESTED',
        'zip_code' => '97212',
        'zip_code_details' => 'YES',
        'phone' => '808-555-1212',
        'email' => 'foo@example.com',
        'first_name' => 'Jonathan',
        'last_name' => 'Doe-Roe',
        'birth_date' => '1900-01-01',
        'ssn' => '6665123456',
        'icn' => '123456V123456'
      }
    }
  end
end
