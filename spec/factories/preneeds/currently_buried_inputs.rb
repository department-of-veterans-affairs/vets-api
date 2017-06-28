# frozen_string_literal: true
FactoryGirl.define do
  factory :currently_buried_input, class: Preneeds::CurrentlyBuriedInput do
    cemetery_number '400' # Alabama National VA Cemetery

    name { attributes_for(:name_input) }
  end
end
