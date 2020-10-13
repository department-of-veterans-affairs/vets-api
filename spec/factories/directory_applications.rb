# frozen_string_literal: true

FactoryBot.define do
  factory :directory_application do
    name { 'MyString' }
    logo_url { 'MyString' }
    type { '' }
    service_cattegories { 'MyText' }
    platforms { 'MyText' }
    app_url { 'MyString' }
    description { 'MyText' }
    privacy_url { 'MyString' }
    tos_url { 'MyString' }
  end
end
