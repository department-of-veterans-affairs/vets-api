# frozen_string_literal: true

FactoryBot.define do
  factory :status_update, class: 'AppealsApi::StatusUpdate' do
    from { 'pending' }
    to { 'submitted' }
    statusable { association(:notice_of_disagreement) }
    status_update_time { Time.zone.now }
  end
end
