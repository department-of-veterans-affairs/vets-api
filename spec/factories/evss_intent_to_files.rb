# frozen_string_literal: true

require 'evss/intent_to_file/intent_to_file'

FactoryBot.define do
  factory :evss_intent_to_file, class: 'EVSS::IntentToFile::IntentToFile' do
    id { 1 }
    creation_date { Time.current }
    expiration_date { 1.year.from_now }
    participant_id { 1 }
    source { 'EBN' }
    status { %w[active incomplete expired].sample }
    type { 'compensation' }

    initialize_with { new(attributes.deep_stringify_keys) }
  end
end
