# frozen_string_literal: true

module Preneeds
  # Models an Applicant from a {Preneeds::BurialForm} form
  #
  # @!attribute applicant_email
  #   @return [String] applicant's email
  # @!attribute applicant_phone_number
  #   @return [String] applicant's phone number
  # @!attribute applicant_relationship_to_claimant
  #   @return [String] applicant's relationship to claimant
  # @!attribute completing_reason
  #   @return [String] completing reason. Currently hard coded.
  # @!attribute mailing_address
  #   @return [Preneeds::Address] applicant's mailing address
  # @!attribute name
  #   @return [Preneeds::FullName] applicant's name
  #
  class Applicant < Preneeds::Base
    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String, default: 'vets.gov application'

    attribute :mailing_address, Preneeds::Address
    attribute :name, Preneeds::FullName

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      {
        applicantEmail: applicant_email, applicantPhoneNumber: applicant_phone_number,
        applicantRelationshipToClaimant: applicant_relationship_to_claimant,
        completingReason: completing_reason, mailingAddress: mailing_address&.as_eoas,
        name: name&.as_eoas
      }
    end

    # List of permitted params for use with Strong Parameters
    #
    # @return [Array] array of class attributes as symbols
    #
    def self.permitted_params
      [
        :applicant_email, :applicant_phone_number, :applicant_relationship_to_claimant, :completing_reason,
        { mailing_address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params }
      ]
    end
  end
end
