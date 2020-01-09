# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form, class: 'VAOS::AppointmentForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :with_other_attributes do
      email { 'judy.morrison@fake.gov' }
      # TODO
    end

    trait :creation do
      # TODO
    end
  end
end
