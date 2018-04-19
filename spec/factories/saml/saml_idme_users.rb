# frozen_string_literal: true

FactoryBot.define do
  factory :saml_idme_user, class: Saml::IdmeUser do
    fname               'John'
    lname               'Adams'
    mname               ''
    social              '11122333'
    gender              'male'
    birth_date          '1735-10-30'

    uuid                '1234abcd'
    email               'john.adams@whitehouse.gov'
    multifactor         'false'
    level_of_assurance  3

    skip_create
  end
end
