# frozen_string_literal: true

FactoryBot.define do
  factory :backend_status do
    name { 'gibs' }
    service_id { 'appeals' }

    initialize_with { new(name:, service_id:) }
  end
end
