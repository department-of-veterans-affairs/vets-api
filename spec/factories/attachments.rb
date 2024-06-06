# frozen_string_literal: true

FactoryBot.define do
  factory :attachment do
    attachment_size { 210_000 }
    message_id { 674_852 }
    name { 'sm_file3.jpg' }
    metadata { {} }
  end
end
