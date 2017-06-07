# frozen_string_literal: true
require 'evss/letters/letter'

FactoryGirl.define do
  factory :letter, class: 'EVSS::Letters::Letter' do
    name 'Benefits Summary Letter'
    letter_type 'benefit_summary'
    initialize_with do
      args = { 'letter_name' => name, 'letter_type' => letter_type }
      new(args)
    end
  end
end
