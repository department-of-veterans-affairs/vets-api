# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class VeteranInput < Common::Base
    include ActiveModel::Validations

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
  end
end
