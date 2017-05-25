# frozen_string_literal: true
FactoryGirl.define do
  factory :letter, class: 'Letter' do
    name 'Benefits Summary Letter'
    letter_type Letter::LETTER_TYPES[:benefits_summary]
    initialize_with { new(name, letter_type) }
  end
end
