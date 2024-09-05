# frozen_string_literal: true

FactoryBot.define do
  factory :vye_pending_document, class: 'Vye::PendingDocument' do
    doc_type { Faker::Lorem.word }
    queue_date { Faker::Date.between(from: 10.days.ago, to: 20.days.ago) }
    rpo { Faker::Lorem.word }
  end
end
