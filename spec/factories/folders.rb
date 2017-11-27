# frozen_string_literal: true
FactoryBot.define do
  factory :folder do
    sequence :id do |n|
      n
    end

    sequence :name do |n|
      "Folder #{n}"
    end

    count 0
    unread_count 0
    system_folder false

    trait :system_folder do
      sequence :name do |n|
        "System Folder #{n}"
      end

      system_folder true
    end

    trait :with_counts do
      count 10
      unread_count 5
    end
  end
end
