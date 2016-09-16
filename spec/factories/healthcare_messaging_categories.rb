# frozen_string_literal: true
FactoryGirl.define do
  skip_create

  factory :category do
    names %w(OTHER APPOINTMENTS MEDICATIONS TEST_RESULTS EDUCATION)
  end
end
