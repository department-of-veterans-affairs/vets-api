# frozen_string_literal: true

FactoryBot.define do
  factory :okta_idme_response, class: Hash do
    profile do
      {
        'lastName' => 'CARROLL',
        'login' => 'ae9ff5f4e4b741389904087d94cd19b2',
        'last_login_type' => 'http://idmanagement.gov/ns/assurance/loa/3',
        'firstName' => 'KELLY',
        'idme_loa' => '3',
        'middleName' => 'D',
        'icn' => '1013062086V794840',
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
        'login' => '1cafa21544034e8caceeeeca5c108600',
        'last_login_type' => 'myhealthevet',
        'firstName' => nil,
        'idme_loa' => '0',
        'middleName' => nil,
        'email' => 'mhvzack_0@example.com',
        'loa' => 0,
        'icn' => '1013062086V794840',
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
        'login' => '1655c16aa0784dbe973814c95bd69177',
        'last_login_type' => 'dslogon',
        'firstName' => 'JOHNNIE',
        'idme_loa' => '0',
        'middleName' => 'Leonard',
        'email' => 'dslogon10923109@example.com',
        'loa' => 2,
        'icn' => '1013062086V794840',
        'dslogon_assurance' => '2'
      }
    end
    initialize_with { { 'profile' => profile } }
  end
end
