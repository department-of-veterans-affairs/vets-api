# frozen_string_literal: true

FactoryBot.define do
  factory :schema_contract_validation, class: 'SchemaContract::Validation' do
    transient do
      user_account { create(:user_account) }
    end
    contract_name { 'test_index' }
    user_account_id { user_account.id }
    user_uuid { '1234' }
    response { { key: 'value' } }
    status { 'initialized' }
  end
end
