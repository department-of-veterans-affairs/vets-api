# frozen_string_literal: true

FactoryBot.define do
  factory :okta_idme_response, class: Hash do
    profile do
      {
        'lastName' => 'CARROLL',
        'gender' => 'F',
        'secondEmail' => null,
        'login' => 'ae9ff5f4e4b741389904087d94cd19b2',
        'ssn' => '123456789',
        'last_login_type' => 'http://idmanagement.gov/ns/assurance/loa/3',
        'firstName' => 'KELLY',
        'idme_loa' => '3',
        'mobilePhone' => nil,
        'dob' => '1998-01-23',
        'middleName' => 'D',
        'email' => 'vets.gov.user+20@gmail.com',
        'loa' => 3
      }
    end
    initialize_with { { 'profile' => profile } }
  end

  factory :okta_mhv_response, class: Hash do
    profile do
      {
        'lastName' => nil,
        'gender' => nil,
        'secondEmail' => nil,
        'login' => '1cafa21544034e8caceeeeca5c108600',
        'ssn' => nil,
        'last_login_type' => 'myhealthevet',
        'firstName' => nil,
        'idme_loa' => '0',
        'mobilePhone' => nil,
        'dob' => nil,
        'middleName' => nil,
        'email' => 'mhvzack_0@example.com',
        'loa' => 0,
        'mhv_profile' => '{"accountType":"Premium","availableServices":{"21":"VA Medications"}}',
        'mhv_icn' => '1013062086V794840',
        'mhv_account_type' => 'Premium',
        'mhv_uuid' => '15093546'
      }
    end
    initialize_with { { 'profile' => profile } }
  end

  factory :okta_dslogon_response, class: Hash do
    profile do
      {
        'lastName' => 'WEAVER',
        'gender' => 'M',
        'secondEmail' => nil,
        'login' => '1655c16aa0784dbe973814c95bd69177',
        'ssn' => '796123607',
        'last_login_type' => 'dslogon',
        'firstName' => 'JOHNNIE',
        'idme_loa' => '0',
        'mobilePhone' => nil,
        'dob' => '1956-07-10',
        'middleName' => 'Leonard',
        'dslogon_edipi' => '1005169255',
        'email' => 'dslogon10923109@example.com',
        'loa' => 2,
        'dslogon_assurance' => '2'
      }
    end
    initialize_with { { 'profile' => profile } }
  end
end
