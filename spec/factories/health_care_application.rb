# frozen_string_literal: true

FactoryBot.define do
  factory :health_care_application do
    form(
      File.read(
        Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
      )
    )
  end
end
