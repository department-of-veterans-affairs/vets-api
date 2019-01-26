# frozen_string_literal: true

FactoryBot.define do
  factory :rate_limited_search do
    search_params('1234')
  end
end
