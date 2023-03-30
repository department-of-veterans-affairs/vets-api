# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a veteran from a {Preneeds::BurialForm} form
  #
  # @!attribute date_of_birth
  #   @return [String] veteran's date of birth
  # @!attribute date_of_death
  #   @return [String] veteran's date of death
  # @!attribute gender
  #   @return [String] veteran's gender
  # @!attribute is_deceased
  #   @return [String] is veteran deceased? 'yes' or 'no'
  # @!attribute marital_status
  #   @return [String] veteran's marital status
  # @!attribute military_service_number
  #   @return [String] veteran's military service number
  # @!attribute place_of_birth
  #   @return [String] veteran's place of birth
  # @!attribute ssn
  #   @return [String] veteran's social security number
  # @!attribute va_claim_number
  #   @return [String] veteran's VA claim number
  # @!attribute military_status
  #   @return [String] veteran's military status
  # @!attribute address
  #   @return [Preneeds::Address] veteran's address
  # @!attribute current_name
  #   @return [Preneeds::FullName] veteran's current name
  # @!attribute service_name
  #   @return [Preneeds::FullName] veteran's name when serving
  # @!attribute service_records
  #   @return [Array<Preneeds::ServiceRecord>] veteran's service records
  #
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

    attribute :race, Preneeds::Race
    attribute :address, Preneeds::Address
    attribute :current_name, Preneeds::FullName
    attribute :service_name, Preneeds::FullName
    attribute :service_records, Array[Preneeds::ServiceRecord]

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      hash = {
        address: address&.as_eoas, currentName: current_name.as_eoas, dateOfBirth: date_of_birth,
        dateOfDeath: date_of_death, gender:,
        race: race&.as_eoas,
        isDeceased: is_deceased,
        maritalStatus: marital_status, militaryServiceNumber: military_service_number,
        placeOfBirth: place_of_birth, serviceName: service_name.as_eoas,
        serviceRecords: service_records.map(&:as_eoas), ssn:, vaClaimNumber: va_claim_number,
        militaryStatus: military_status
      }

      %i[
        dateOfBirth dateOfDeath vaClaimNumber placeOfBirth militaryServiceNumber
      ].each { |key| hash.delete(key) if hash[key].blank? }

      hash
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      [
        :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
        :military_service_number, :place_of_birth, :ssn, :va_claim_number, :military_status,
        { race: Preneeds::Race.permitted_params,
          address: Preneeds::Address.permitted_params,
          current_name: Preneeds::FullName.permitted_params,
          service_name: Preneeds::FullName.permitted_params,
          service_records: [Preneeds::ServiceRecord.permitted_params] }
      ]
    end
  end
end
