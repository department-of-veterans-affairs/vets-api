FactoryBot.define do
  factory :tooltip do
    user_account { nil }
    tooltip_name { "MyString" }
    last_signed_in { "2025-02-07 03:39:51" }
    counter { 1 }
    hidden { false }
  end
end
