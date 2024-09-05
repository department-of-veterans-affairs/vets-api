# frozen_string_literal: true

require 'va_profile/demographics/preferred_name_response'

FactoryBot.define do
  factory :preferred_name, class: 'VAProfile::Models::PreferredName' do
    text { 'Pat' }
    source_system_user { '123498767V234859' }
    source_date { Time.current }

    initialize_with { new(attributes) }
  end

  factory :preferred_name_response, class: 'VAProfile::Demographics::PreferredNameResponse' do
    initialize_with { new(200, preferred_name: build(:preferred_name)) }
  end
end
