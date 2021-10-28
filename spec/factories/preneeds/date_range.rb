# frozen_string_literal: true

FactoryBot.define do
  factory :date_range, class: 'Preneeds::DateRange' do
    from { '1940-08-07' }
    to { '1945-08-07' }
  end
end
