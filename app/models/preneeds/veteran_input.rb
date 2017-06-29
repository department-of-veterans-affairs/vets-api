# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class VeteranInput < Common::Base
    include ActiveModel::Validations

    validate :validate_address, if: -> (v) { v.address.present? }
    validate :validate_current_name, if: -> (v) { v.current_name.present? }
    validate :validate_service_name, if: -> (v) { v.service_name.present? }
    validate :validate_service_records, if: -> (v) { v.service_records.present? }

    validates :current_name, :service_name, :service_records, presence: true
    validates :date_of_birth, :date_of_death, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, allow_blank: true }
    validates :gender, inclusion: { in: %w(Male Female) }
    validates :is_deceased, inclusion: { in: %w(yes no unsure) }
    validates :marital_status, inclusion: { in: %w(Single Separated Married Divorced Widowed) }
    validates :military_service_number, :va_claim_number, length: { maximum: 9 }
    validates :place_of_birth, length: { maximum: 100 }
    validates :ssn, format: /\A\d{3}-\d{2}-\d{4}\z/
    validates :military_status, inclusion: { in: %w(A R S V X E D O I) }

    attribute :address, AddressInput
    attribute :current_name, NameInput
    attribute :date_of_birth, XmlDate
    attribute :date_of_death, XmlDate
    attribute :gender, String
    attribute :is_deceased, String
    attribute :marital_status, String
    attribute :military_service_number, String
    attribute :place_of_birth, String
    attribute :service_name, NameInput
    attribute :service_records, Array[ServiceRecordInput]
    attribute :ssn, String
    attribute :va_claim_number, String
    attribute :military_status, String

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
        address: AddressInput.permitted_params, current_name: NameInput.permitted_params,
        service_name: NameInput.permitted_params, service_records: [ServiceRecordInput.permitted_params]
      ]
    end

    private

    def validate_current_name
      errors.add(:current_name, current_name.errors.full_messages.join(', ')) unless current_name.valid?
    end

    def validate_address
      errors.add(:address, address.errors.full_messages.join(', ')) unless address.valid?
    end

    def validate_service_name
      errors.add(:service_name, service_name.errors.full_messages.join(', ')) unless service_name.valid?
    end

    def validate_service_records
      service_records_errors = service_records.each_with_object([]) do |service_record, o|
        o << service_record.errors.full_messages.join(', ') unless service_record.valid?
      end

      errors.add(:service_records, service_records_errors.join(', ')) if service_records_errors.present?
    end
  end
end
