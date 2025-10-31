# frozen_string_literal: true

FactoryBot.define do
  factory :form212680, class: 'SavedClaim::Form212680' do
    form_id { SavedClaim::Form212680::FORM }
    form {
      VetsJsonSchema::EXAMPLES['21-2680'].to_s
    }
  end
end
