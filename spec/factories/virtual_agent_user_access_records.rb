# frozen_string_literal: true

FactoryBot.define do
  factory :create_virtual_agent_user_access_record do
    action_type { 'MyString' }
    first_name { 'MyString' }
    last_name { 'MyString' }
    ssn { 'MyString' }
    icn { 'MyString' }
  end
end
