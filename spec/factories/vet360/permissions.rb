# frozen_string_literal: true

FactoryBot.define do
  factory :permission, class: 'Vet360::Models::Permission' do
    permission_type { 'TextPermission' }
    permission_value { true }
    sequence(:id) { |n| n }
    sequence(:transaction_id, 100) { |n| "d2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date  { '2019-09-23T11:52:03-06:00' }
    created_at   { '2019-09-23T11:52:03-06:00' }
    updated_at   { '2019-09-24T11:52:03-06:00' }
    vet360_id { '12345' }
  end
end
