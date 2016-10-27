# frozen_string_literal: true
FactoryGirl.define do
  factory :category do
    message_category_type %w(OTHER APPOINTMENTS MEDICATIONS TEST_RESULTS EDUCATION)
  end
end
