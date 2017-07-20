# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class Claimant < Common::Base
    include ActiveModel::Validations

    attribute :date_of_birth, XmlDate
    attribute :desired_cemetery, String
    attribute :email, String
    attribute :phone_number, String
    attribute :relationship_to_vet, String
    attribute :ssn, String

    attribute :name, Preneeds::Name
    attribute :address, Preneeds::Address

    def message
      hash = {
        address: address.message, dateOfBirth: date_of_birth, desiredCemetery: desired_cemetery,
        email: email, name: name.message, phoneNumber: phone_number,
        relationshipToVet: relationship_to_vet, ssn: ssn
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
