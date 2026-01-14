# frozen_string_literal: true

FactoryBot.define do
  factory :form212680, class: 'SavedClaim::Form212680' do
    form_id { SavedClaim::Form212680::FORM }
    form {
      VetsJsonSchema::EXAMPLES['21-2680'].to_json.to_s
    }
  end

  factory :form212680Simple, class: 'SavedClaim::Form212680' do
    transient do
      country { 'USA' }
    end

    form {
      example = VetsJsonSchema::EXAMPLES.fetch('21-2680-SIMPLE').clone
      example['claimantInformation']['address']['country'] = country
      example.to_json.to_s
    }
    form_id { SavedClaim::Form212680::FORM }
  end
end
