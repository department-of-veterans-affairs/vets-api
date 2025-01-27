# frozen_string_literal: true

FactoryBot.define do
  factory :notification, class: 'VANotify::Notification' do
    notification_id { SecureRandom.uuid }
    reference { nil }
    to { 'email@email.com' }
    status {
      %w[temporary-failure permanent-failure technical-failure preferences-declined pending pending-virus-check
         virus-scan-failed validation-failed failed created sending delivered sent].sample
    }
    completed_at { Time.zone.now }
    sent_at { Time.zone.now }
    notification_type { %w[Email sms].sample }
    status_reason {
      [
        'Failed to deliver email due to hard bounce',
        'Temporarily failed to deliver email due to soft bounce',
        'Requested identifier not found in MPI correlation database',
        'Contact preferences set to false',
        'Mpi Profile not found for this identifier',
        'Unreachable destination handset',
        'No contact info found from VA Profile',
        'No recipient opt-in found for explicit preference'
      ].sample
    }
    provider { %w[ses twilio pinpoint].sample }
    source_location { 'SomeTeam' }
    callback_klass {}
    callback_metadata { {} }
    template_id { SecureRandom.uuid }
  end
end
