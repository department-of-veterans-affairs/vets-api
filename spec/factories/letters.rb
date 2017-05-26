# frozen_string_literal: true
FactoryGirl.define do
  factory :letter, class: 'Letter' do
    name 'Benefits Summary Letter'
    letter_type Letter::LETTER_TYPES[:benefits_summary]
    initialize_with do
      args = { name: name, letter_type: letter_type }
      new(args)
    end
  end
end
