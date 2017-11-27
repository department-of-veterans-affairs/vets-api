# frozen_string_literal: true
FactoryBot.define do
  sequence(:last_name) { |n| "last #{n}" }
  sequence(:first_name) { |n| "first #{n}" }
  sequence(:middle_name) { |n| "middle #{n}" }
  sequence(:maiden_name) { |n| "maiden #{n}" }
  sequence(:street) { |n| "street #{n}" }
  sequence(:street2) { |n| "street2 #{n}" }
end
