# frozen_string_literal: true

FactoryBot.define do
  factory :cemetery, class: 'Preneeds::Cemetery' do
    cemetery_type { 'N' }
    sequence(:name) { |n| "Cemetery #{n}" }
    sequence(:num) { |n|  n.to_s.rjust(3, '0') }
  end
end
