# frozen_string_literal: true
FactoryGirl.define do
  factory :military_rank, class: Preneeds::MilitaryRank do
    sequence(:branch_of_service_cd) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr }
    officer_ind 'N'
    activated_one_date '1947-09-18T04:00:00.000Z'
    activated_two_date '1947-09-18T04:00:00.000Z'
    activated_three_date '1947-09-18T04:00:00.000Z'
    deactivated_one_date '1947-09-18T04:00:00.000Z'
    deactivated_two_date '1947-09-18T04:00:00.000Z'
    deactivated_three_date '1947-09-18T04:00:00.000Z'

    military_rank_detail { attributes_for(:military_rank_detail) }
  end
end
