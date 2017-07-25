# frozen_string_literal: true
FactoryGirl.define do
  factory :date_range, class: Preneeds::DateRange do
    from '1940-08-07'
    to '1945-08-07'
  end
end
