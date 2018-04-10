# frozen_string_literal: true

FactoryBot.define do
  factory :vet360_address, class: 'Vet360::Models::Address' do
    address_line_1 '123 Main Street'
    address_pou 'RESIDENCE/CHOICE'
    city 'Denver'
    country 'USA'
    state_abbr 'CO'
    zip_code '80202'
    sequence(:id) { |n| n }
    sequence(:transaction_id, 100) { |n| "#{n}" }
    confirmation_date    '2017-04-09T11:52:03-06:00'
    effective_start_date '2017-04-09T11:52:03-06:00'
    effective_end_date   nil
    source_date          '2018-04-09T11:52:03-06:00'
    created_at           '2017-04-09T11:52:03-06:00'
    updated_at           '2017-04-09T11:52:03-06:00'

    trait :mailing do
      address_pou 'CORRESPONDENCE'
      address_line_1 '1515 Broadway'
    end
  end
end
