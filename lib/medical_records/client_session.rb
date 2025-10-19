# frozen_string_literal: true

require 'common/client/session'

module MedicalRecords
  class ClientSession < Common::Client::Session
    attribute :user_uuid, String
    attribute :patient_fhir_id, Integer
    attribute :refresh_time, Date

    redis_store REDIS_CONFIG[:medical_records_store][:namespace]
    redis_ttl REDIS_CONFIG[:medical_records_store][:each_ttl]
    redis_key :user_uuid
  end
end
