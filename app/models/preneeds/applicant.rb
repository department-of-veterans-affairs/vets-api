# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class Applicant < Preneeds::Base
    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String, default: 'vets.gov application'

    attribute :mailing_address, Preneeds::Address
    attribute :name, Preneeds::FullName

    # Hash attributes must correspond to xsd ordering or API call will fail
    def as_eoas
      {
        applicantEmail: applicant_email, applicantPhoneNumber: applicant_phone_number,
        applicantRelationshipToClaimant: applicant_relationship_to_claimant,
        completingReason: completing_reason, mailingAddress: mailing_address&.as_eoas,
        name: name&.as_eoas
      }
    end

    def self.permitted_params
      [
        :applicant_email, :applicant_phone_number, :applicant_relationship_to_claimant, :completing_reason,
        mailing_address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params
      ]
    end
  end
end
