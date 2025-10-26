# frozen_string_literal: true

FactoryBot.define do
  factory :va12680, class: 'SavedClaim::Form212680' do
    form { Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-2680' 'simple.json').read }
  end
end
