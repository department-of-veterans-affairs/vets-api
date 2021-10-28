# frozen_string_literal: true

FactoryBot.define do
  factory :ask, class: 'SavedClaim::Ask' do
    form { VetsJsonSchema::EXAMPLES['0873'].clone.to_json }
  end
end
