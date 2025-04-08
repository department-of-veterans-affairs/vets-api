# frozen_string_literal: true

require 'disability_compensation/responses/intent_to_files_response'

FactoryBot.define do
  factory :disability_compensation_intent_to_file, class: 'DisabilityCompensation::ApiProvider::IntentToFile' do
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
