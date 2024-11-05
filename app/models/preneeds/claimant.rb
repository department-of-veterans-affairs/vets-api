# frozen_string_literal: true

module Preneeds
  # Models an Claimant from a {Preneeds::BurialForm} form
  #
  # @!attribute date_of_birth
  #   @return [String] claimant date of birth
  # @!attribute desired_cemetery
  #   @return [String] cemetery number
  # @!attribute email
  #   @return [String] claimant email
  # @!attribute phone_number
  #   @return [String] claimant phone number
  # @!attribute relationship_to_vet
  #   @return [String] code representing claimant's relationship to servicemember; one of '1', '2', '3', or '4'
  # @!attribute ssn
  #   @return [String] claimant's social security number
  # @!attribute name
  #   @return [Preneeds::FullName] claimant's full name
  # @!attribute address
  #   @return [Preneeds::Address] claimant's address
  #
  class Claimant < Preneeds::Base
    attribute :date_of_birth, String
    attribute :desired_cemetery, String
    attribute :email, String
    attribute :phone_number, String
    attribute :relationship_to_vet, String
    attribute :ssn, String

    attribute :name, Preneeds::FullName
    attribute :address, Preneeds::Address

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      hash = {
        address: address&.as_eoas, dateOfBirth: date_of_birth, desiredCemetery: desired_cemetery,
        email:, name: name&.as_eoas, phoneNumber: phone_number,
        relationshipToVet: relationship_to_vet, ssn:
      }

      %i[email phoneNumber desiredCemetery].each { |key| hash.delete(key) if hash[key].blank? }
      hash
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      [
        :date_of_birth, :desired_cemetery, :email, :completing_reason, :phone_number, :relationship_to_vet, :ssn,
        { address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params }
      ]
    end
  end
end
