# frozen_string_literal: true

FactoryBot.define do
  factory :vye_pending_document, class: 'Vye::PendingDocument' do
    claim_no { Faker::Lorem.word }
    doc_type { Faker::Lorem.word }
    queue_date { Faker::Time.backward(days: 14) }
    rpo { Faker::Lorem.word }
  end
end
