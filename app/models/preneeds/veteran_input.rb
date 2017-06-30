# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class VeteranInput < Common::Base
    include ActiveModel::Validations

    # ACTIVE_DUTY("A", "ACTIVE DUTY"), RETIRED("R", "RETIRED"),
    # RESERVE_NATIONAL_GUARD("S", "RESERVE/NATIONAL GUARD"),
    # VETERAN("V", "VETERAN"), OTHER_UNKNOWN("X", "OTHER/UNKNOWN"),
    # OTHER("X", "OTHER"), RETIRED_ACTIVE_DUTY("E", "RETIRED ACTIVE DUTY"),
    # DIED_ON_ACTIVE_DUTY("D", "DIED ON ACTIVE DUTY"),
    # RETIRED_RESERVE_NATIONAL_GUARD("O", "RETIRED RESERVE OR NATIONAL GUARD"),
    # DEATH_INACTIVE_DUTY("I", "DEATH RELATED TO INACTIVE DUTY TRAINING");
    MILITARY_STATUSES = %w(A R S V X E D O I).freeze
    DECEASED_STATUSES = %w(yes no unsure).freeze
    GENDERS = %w(Male Female).freeze
    MARITAL_STATUSES = %w(Single Separated Married Divorced Widowed).freeze

    attribute :date_of_birth, XmlDate
    attribute :date_of_death, XmlDate
    attribute :gender, String
    attribute :is_deceased, String
    attribute :marital_status, String
    attribute :military_service_number, String
    attribute :place_of_birth, String
    attribute :ssn, String
    attribute :va_claim_number, String
    attribute :military_status, String

    attribute :address, Preneeds::AddressInput
    attribute :current_name, Preneeds::NameInput
    attribute :service_name, Preneeds::NameInput
    attribute :service_records, Array[Preneeds::ServiceRecordInput]

    validates :date_of_birth, :date_of_death, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, allow_blank: true }
    validates :gender, inclusion: { in: GENDERS }
    validates :is_deceased, inclusion: { in: DECEASED_STATUSES }
    validates :marital_status, inclusion: { in: MARITAL_STATUSES }
    validates :military_service_number, :va_claim_number, length: { maximum: 9 }
    validates :place_of_birth, length: { maximum: 100 }
    validates :ssn, format: /\A\d{3}-\d{2}-\d{4}\z/
    validates :military_status, inclusion: { in: MILITARY_STATUSES }

    validates :current_name, :service_name, :service_records, presence: true, preneeds_embedded_object: true
    validates :address, preneeds_embedded_object: true

    def message
      hash = {
        address: address&.message, current_name: current_name.message, date_of_birth: date_of_birth,
        date_of_death: date_of_death, gender: gender, is_deceased: is_deceased,
        marital_status: marital_status, military_service_number: military_service_number,
        place_of_birth: place_of_birth, service_name: service_name.message,
        service_records: service_records.map(&:message), ssn: ssn, va_claim_number: va_claim_number,
        military_status: military_status
      }

      [:date_of_birth, :date_of_death, :place_of_birth].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    def self.permitted_params
      [
        :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
        :military_service_number, :place_of_birth, :ssn, :va_claim_number, :military_status,
        address: Preneeds::AddressInput.permitted_params, current_name: Preneeds::NameInput.permitted_params,
        service_name: Preneeds::NameInput.permitted_params,
        service_records: [Preneeds::ServiceRecordInput.permitted_params]
      ]
    end
  end
end
