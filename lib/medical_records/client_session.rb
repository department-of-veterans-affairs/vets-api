# frozen_string_literal: true

require 'common/client/session'

module MedicalRecords
  class ClientSession < Common::Client::Session
    attribute :patient_fhir_id, Integer
    attribute :icn, String

    redis_store REDIS_CONFIG[:medical_records_store][:namespace]
    redis_ttl 900
    redis_key :user_id
    redis_key :patient_fhir_id
  end
end
