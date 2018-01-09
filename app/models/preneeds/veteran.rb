# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class Veteran < Preneeds::Base
    attribute :date_of_birth, String
    attribute :date_of_death, String
    attribute :gender, String
    attribute :is_deceased, String
    attribute :marital_status, String
    attribute :military_service_number, String
    attribute :place_of_birth, String
    attribute :ssn, String
    attribute :va_claim_number, String
    attribute :military_status, String

    attribute :address, Preneeds::Address
    attribute :current_name, Preneeds::FullName
    attribute :service_name, Preneeds::FullName
    attribute :service_records, Array[Preneeds::ServiceRecord]

    def as_eoas
      hash = {
        address: address&.as_eoas, currentName: current_name.as_eoas, dateOfBirth: date_of_birth,
        dateOfDeath: date_of_death, gender: gender, isDeceased: is_deceased,
        maritalStatus: marital_status, militaryServiceNumber: military_service_number,
        placeOfBirth: place_of_birth, serviceName: service_name.as_eoas,
        serviceRecords: service_records.map(&:as_eoas), ssn: ssn, vaClaimNumber: va_claim_number,
        militaryStatus: military_status
      }

      [
        :dateOfBirth, :dateOfDeath, :vaClaimNumber,
        :placeOfBirth, :militaryServiceNumber
      ].each { |key| hash.delete(key) if hash[key].blank? }

      hash
    end

    def self.permitted_params
      [
        :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
        :military_service_number, :place_of_birth, :ssn, :va_claim_number, :military_status,
        address: Preneeds::Address.permitted_params,
        current_name: Preneeds::FullName.permitted_params,
        service_name: Preneeds::FullName.permitted_params,
        service_records: [Preneeds::ServiceRecord.permitted_params]
      ]
    end
  end
end
