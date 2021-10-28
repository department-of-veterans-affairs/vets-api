# frozen_string_literal: true

FactoryBot.define do
  factory :preneeds_attachment_type, class: 'Preneeds::AttachmentType' do
    sequence(:attachment_type_id) { |n| n }
    sequence(:description) { |n| "#{n} description" }
  end
end
