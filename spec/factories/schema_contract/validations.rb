# frozen_string_literal: true

FactoryBot.define do
  factory :schema_contract_validation, class: 'SchemaContract::Validation' do
    contract_name { 'test_index' }
    user_uuid { '1234' }
    response { { key: 'value' } }
    status { 'initialized' }
  end
end
