# frozen_string_literal: true

FactoryBot.define do
  factory :std_zipcode do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    zip_code { '15212' }
    state_id { 1_009_342 }
    county_number { 3 }
  end
end
