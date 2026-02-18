# frozen_string_literal: true

FactoryBot.define do
  factory :digital_forms_api_schema, class: Hash do
    skip_create

    properties do
      {
        'contentName' => { 'type' => 'string' },
        'providerData' => { 'type' => 'object' }
      }
    end

    required { nil }

    initialize_with do
      schema = { 'type' => 'object', 'properties' => properties }
      schema['required'] = required if required
      schema
    end

    trait :with_required do
      required { %w[contentName providerData] }
    end
  end

  factory :digital_forms_api_schema_response, class: Hash do
    skip_create

    schema_body { build(:digital_forms_api_schema) }
    nested { false }

    initialize_with do
      nested ? { 'data' => { 'schema' => schema_body } } : schema_body
    end
  end
end
