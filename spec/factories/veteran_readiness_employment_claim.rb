# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claim, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900' }

    transient do
      main_phone { '2222222222' }
      cell_phone { '3333333333' }
      international_number { '+4444444444' }
      email { 'email@test.com' }
      is_moving { true }
      years_of_ed { '10' }
      country { 'USA' }
      postal_code { '10001' }
      first { 'First' }
      middle { 'Middle' }
      last { 'Last' }
      dob { '1980-01-01' }
      privacyAgreementAccepted { true }
    end

    form {
      {
        'mainPhone' => main_phone,
        'cellPhone' => cell_phone,
        'internationalNumber' => international_number,
        'email' => email,
        'newAddress' => {
          'country' => country,
          'street' => '13 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => postal_code
        },
        'isMoving' => is_moving,
        'veteranAddress' => {
          'country' => country,
          'street' => '12 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => postal_code
        },
        'yearsOfEducation' => years_of_ed,
        'veteranInformation' => {
          'fullName' => {
            'first' => first,
            'middle' => middle,
            'last' => last,
            'suffix' => 'III'
          },
          'dob' => dob
        },
        'privacyAgreementAccepted' => privacyAgreementAccepted
      }.to_json
    }
  end

  factory :veteran_readiness_employment_claim_minimal, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900' }

    form {
      {
        'email' => 'email@test.com',
        'isMoving' => false,
        'yearsOfEducation' => '10',
        'veteranInformation' => {
          'fullName' => {
            'first' => 'First',
            'last' => 'Last'
          },
          'dob' => '1980-01-01'
        },
        'privacyAgreementAccepted' => true
      }.to_json
    }
  end
end
