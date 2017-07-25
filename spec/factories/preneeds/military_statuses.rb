# frozen_string_literal: true
FactoryGirl.define do
  factory :military_status, class: Preneeds::MilitaryStatus do
    veteran true
    retired_active_duty true
    died_on_active_duty true
    retired_reserve true
    death_inactive_duty true
    other true
  end
end
