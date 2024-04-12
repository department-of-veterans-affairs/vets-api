# spec/factories/pega_tables.rb
FactoryBot.define do
  factory :pega_table do
    uuid { 'c47bec59-02c7-43e4-a0f7-acf287a32a97' }
    veteranfirstname { 'John' }
    veteranlastname { 'Doe' }

    trait :with_valid_response do
      response { '{"status": 200}' }
    end

    trait :with_invalid_response do
      response { '{"status": 400}' }
    end

    trait :with_invalid_json_response do
      response { 'invalid_json' }
    end
  end
end

