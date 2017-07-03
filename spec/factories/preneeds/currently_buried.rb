# frozen_string_literal: true
FactoryGirl.define do
  factory :currently_buried, class: Preneeds::CurrentlyBuried do
    cemetery_number '400' # Alabama National VA Cemetery

    name { attributes_for(:name) }
  end
end
