# frozen_string_literal: true
FactoryGirl.define do
  factory :branches_of_service, class: Preneeds::BranchesOfService do
    sequence(:code) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr }
    begin_date '1926-07-02T04:00:00.000Z'
    end_date '1926-07-02T04:00:00.000Z'
    sequence(:flat_full_descr) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr + ' flat_full_descr' }
    sequence(:full_descr) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr + ' full_descr' }
    sequence(:short_descr) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr + ' short_descr' }
    state_required 'Y'
    sequence(:upright_full_descr) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr + ' upright_full_descr' }
  end
end
