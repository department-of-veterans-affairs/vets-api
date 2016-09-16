# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefit_form, class: OpenStruct do
    fullName do
      first { 'Mark' }
      last { 'Olson' }
    end
    initialize_with { OpenStruct.new }
  end
end
