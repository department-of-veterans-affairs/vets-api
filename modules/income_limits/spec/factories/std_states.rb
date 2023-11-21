# frozen_string_literal: true

FactoryBot.define do
  factory :std_state do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    name { 'Pennsylvania' }
    postal_name { 'PA' }
    fips_code { 42 }
    country_id { 1_006_840 }
  end
end
