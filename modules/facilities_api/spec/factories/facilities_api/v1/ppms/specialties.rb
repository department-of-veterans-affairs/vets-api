# frozen_string_literal: true

FactoryBot.define do
  factory :facilities_api_v1_ppms_specialty, class: FacilitiesApi::V1::PPMS::Specialty do
    classification { Faker::IndustrySegments.industry }
    grouping { Faker::IndustrySegments.super_sector }
    name { Faker::IndustrySegments.sector }
    specialization { Faker::IndustrySegments.sub_sector }
    specialty_code { Faker::Alphanumeric.alphanumeric(number: 10, min_alpha: 3) }
    specialty_description { Faker::Marketing.buzzwords }
  end
end
