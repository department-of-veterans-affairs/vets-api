# frozen_string_literal: true

FactoryBot.define do
  factory :representative, class: 'Veteran::Service::Representative' do
    representative_id { '1234' }
    poa_codes { ['A1Q'] }
  end
end
