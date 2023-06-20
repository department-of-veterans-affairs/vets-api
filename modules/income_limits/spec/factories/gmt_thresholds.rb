# frozen_string_literal: true

FactoryBot.define do
  factory :gmt_threshold do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 123844.000000000 UTC +0000' }
    effective_year { 2020 }
    state_name { 'Pennsylvania' }
    county_name { 'Allegheny County' }
    fips { 42_003 }
    trhd1 { 46_500 }
    trhd2 { 53_150 }
    trhd3 { 59_800 }
    trhd4 { 66_400 }
    trhd5 { 71_750 }
    trhd6 { 77_050 }
    trhd7 { 82_350 }
    trhd8 { 87_650 }
    msa { 6280 }
  end
end
