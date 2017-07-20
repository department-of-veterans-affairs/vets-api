# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class Veteran < Preneeds::Base
    attribute :date_of_birth, XmlDate
    attribute :date_of_death, XmlDate
    attribute :gender, String
    attribute :is_deceased, String
    attribute :marital_status, String
    attribute :military_service_number, String
    attribute :place_of_birth, String
    attribute :ssn, String
    attribute :va_claim_number, String
    attribute :military_status, Array[String]

    attribute :address, Preneeds::Address
    attribute :current_name, Preneeds::Name
    attribute :service_name, Preneeds::Name
    attribute :service_records, Array[Preneeds::ServiceRecord]

    def message
      hash = {
        address: address&.message, currentName: current_name.message, dateOfBirth: date_of_birth,
        dateOfDeath: date_of_death, gender: gender, isDeceased: is_deceased,
        maritalStatus: marital_status, militaryServiceNumber: military_service_number,
        placeOfBirth: place_of_birth, serviceName: service_name.message,
        serviceRecords: service_records.map(&:message), ssn: ssn, vaClaimNumber: va_claim_number,
        militaryStatus: military_status
      }

      [:dateOfBirth, :dateOfDeath, :placeOfBirth].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    def self.permitted_params
      [
        :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
        :military_service_number, :place_of_birth, :ssn, :va_claim_number,
        military_status: [], address: Preneeds::Address.permitted_params,
        current_name: Preneeds::Name.permitted_params, service_name: Preneeds::Name.permitted_params,
        service_records: [Preneeds::ServiceRecord.permitted_params]
      ]
    end
  end
end
