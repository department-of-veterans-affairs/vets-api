# frozen_string_literal: true
FactoryGirl.define do
  factory :currently_buried_person, class: Preneeds::CurrentlyBuriedPerson do
    cemetery_number '400' # Alabama National VA Cemetery

    name { attributes_for(:name) }
  end
end
