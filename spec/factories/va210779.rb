# frozen_string_literal: true

FactoryBot.define do
  factory :va210779, class: 'SavedClaim::Form210779' do
    form { VetsJsonSchema::EXAMPLES.fetch('21-0779-SIMPLE').to_json }
    form_id { '21-0779' }
  end
end
