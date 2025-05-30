# frozen_string_literal: true

require 'common/client/session'

module MedicalRecords
  class ClientSession < Common::Client::Session
    attribute :patient_fhir_id, Integer
    attribute :icn, String
    attribute :refresh_time, Date

    redis_store REDIS_CONFIG[:medical_records_store][:namespace]
    redis_ttl REDIS_CONFIG[:medical_records_store][:each_ttl]
    redis_key :icn
  end
end
