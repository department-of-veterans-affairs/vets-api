# frozen_string_literal: true

FactoryBot.define do
  factory :iam_user_identity, class: 'IAMUserIdentity' do
    authn_context { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
    email { 'va.api.user+idme.008@gmail.com' }
    first_name { 'GREG' }
    middle_name { 'A' }
    last_name { 'ANDERSON' }
    gender { 'M' }
    birth_date { '1970-08-12' }
    zip { '78665' }
    ssn { '796121200' }
    iam_sec_id { '0000028114' }
    iam_icn { '1008596379V859838' }
    multifactor { false }
    iam_edipi { '1005079124' }

    sign_in do
      {
        service_name: 'iam_ssoe'
      }
    end

    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end
  end
end
