# frozen_string_literal: true

FactoryBot.define do
  factory :va21680, class: 'SavedClaim::Form212680' do
    form { VetsJsonSchema::EXAMPLES.fetch('21-2680-SIMPLE').to_s }
    form_id { '21-2680' }
  end
end
