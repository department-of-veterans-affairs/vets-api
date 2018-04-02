# frozen_string_literal: true

FactoryBot.define do
  factory :saml_dslogon_user, class: Saml::DslogonUser do
    dslogon_status      'SPONSOR'
    dslogon_assurance   '2'
    dslogon_gender      'male'
    dslogon_deceased    'false'
    dslogon_idtype      'ssn'
    dslogon_uuid        '1016980877'
    dslogon_birth_date  '1973-09-03'
    dslogon_fname       'KENT'
    dslogon_lname       'WELLS'
    dslogon_mname       'Mayo'
    dslogon_idvalue     '796178410'

    uuid                'cf0f3deb1b424d3cb4f792e8346a4d71'
    email               'fake.user@vets.gov'
    multifactor         'false'
    level_of_assurance  nil

    skip_create
  end
end
