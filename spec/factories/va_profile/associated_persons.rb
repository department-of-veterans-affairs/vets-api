# frozen_string_literal: true

require 'va_profile/models/associated_person'

FactoryBot.define do
  factory :associated_person, class: 'VAProfile::Models::AssociatedPerson' do
    address_line1 { '9758 TEST AVE' }
    address_line2 { nil }
    address_line3 { nil }
    city { 'ALBUQUERQUE' }
    contact_type { 'Emergency Contact' }
    family_name { 'Bishop' }
    given_name { 'Ethan' }
    middle_name { 'Jeremy' }
    primary_phone { '(439)573-8274' }
    relationship { 'BROTHER' }
    state { 'NM' }
    zip_code { '87109' }
  end
end
