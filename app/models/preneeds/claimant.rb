# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class Claimant < Common::Base
    include ActiveModel::Validations

    attribute :date_of_birth, XmlDate
    attribute :desired_cemetery, Integer
    attribute :email, String
    attribute :phone_number, String
    attribute :relationship_to_vet, String
    attribute :ssn, String

    attribute :name, Preneeds::Name
    attribute :address, Preneeds::Address

    # Removed length validation on email for now: bad xsd validation
    validates :date_of_birth, format: { with: /\A\d{4}-\d{2}-\d{2}\z/ }
    validates :desired_cemetery, numericality: { only: :integer, greater_than: 0, less_than: 1000 }
    validates :email, format: { with: /\A[a-zA-Z0-9_.+-]+@[a-zA-Z0-9_+-]+\.[a-zA-Z]+\z/, allow_blank: true }
    validates :phone_number, format: { with: /\A[0-9+\s-]{0,20}\z/ }
    validates :relationship_to_vet, inclusion: { in: %w(1 2 3) }
    validates :ssn, format: { with: /\A\d{3}-\d{2}-\d{4}\z/ }

    validates :name, :address, presence: true, preneeds_embedded_object: true

    def message
      hash = {
        address: address.message, date_of_birth: date_of_birth, desired_cemetery: desired_cemetery,
        email: email, name: name.message, phone_number: phone_number,
        relationship_to_vet: relationship_to_vet, ssn: ssn
      }

      [:email, :phone_number].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end

    def self.permitted_params
      [
        :date_of_birth, :desired_cemetery, :email, :completing_reason, :phone_number, :relationship_to_vet, :ssn,
        address: Preneeds::Address.permitted_params, name: Preneeds::Name.permitted_params
      ]
    end
  end
end
