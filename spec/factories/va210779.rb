# frozen_string_literal: true

FactoryBot.define do
  factory :va210779, class: 'SavedClaim::Form210779' do
    form { VetsJsonSchema::EXAMPLES.fetch('21-0779-SIMPLE').deep_dup.to_json }
    form_id { '21-0779' }
  end

  factory :va210779_countries, class: 'SavedClaim::Form210779' do
    form {
      example = VetsJsonSchema::EXAMPLES.fetch('21-0779-SIMPLE').deep_dup
      example['nursingHomeInformation']['nursingHomeAddress']['country'] = 'USA'
      example.to_json
    }
    form_id { '21-0779' }
  end

  factory :va210779_invalid, class: 'SavedClaim::Form210779' do
    form {
      example = VetsJsonSchema::EXAMPLES.fetch('21-0779-SIMPLE').deep_dup
      example['veteranInformation']['fullName']['first'] = nil
      example.to_json
    }
    form_id { '21-0779' }
  end
end
