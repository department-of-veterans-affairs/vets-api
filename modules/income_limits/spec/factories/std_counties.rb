# frozen_string_literal: true

FactoryBot.define do
  factory :std_county do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    name { 'Allegheny' }
    county_number { 3 }
    description { 'The county of Allegheny' }
    state_id { 1_009_342 }
  end
end
