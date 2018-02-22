# frozen_string_literal: true

FactoryBot.define do
  factory :military_rank_detail, class: Preneeds::MilitaryRankDetail do
    sequence(:branch_of_service_code) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr }
    sequence(:rank_code) { |n| "rank #{n} code" }
    sequence(:rank_descr) { |n| "rank #{n} descr" }
  end
end
