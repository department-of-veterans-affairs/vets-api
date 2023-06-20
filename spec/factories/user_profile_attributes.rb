# frozen_string_literal: true

FactoryBot.define do
  factory :user_profile_attributes, class: 'UserProfileAttributes' do
    uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
    email { 'abraham.lincoln@vets.gov' }
    first_name { 'abraham' }
    icn { '123498767V234859' }
    last_name { 'lincoln' }
    ssn { '796111863' }
  end
end
