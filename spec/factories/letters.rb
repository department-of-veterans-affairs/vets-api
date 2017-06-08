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

FactoryGirl.define do
  factory :letter_address, class: 'EVSS::Letters::Address' do
    full_name 'Homer Simpson'
    address_line1 '742 Evergreen Terrace'
    address_line2 nil
    address_line3 nil
    city 'Springfield'
    state 'OR'
    country 'USA'
    foreign_code nil
    zip_code '97475'
  end
end
