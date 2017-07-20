# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class Applicant < Common::Base
    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String

    attribute :mailing_address, Preneeds::Address
    attribute :name, Preneeds::Name

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      {
        applicantEmail: applicant_email, applicantPhoneNumber: applicant_phone_number,
        applicantRelationshipToClaimant: applicant_relationship_to_claimant,
        completingReason: completing_reason, mailingAddress: mailing_address.message,
        name: name.message
      }
    end

    def self.permitted_params
      [
        :applicant_email, :applicant_phone_number, :applicant_relationship_to_claimant, :completing_reason,
        mailing_address: Preneeds::Address.permitted_params, name: Preneeds::Name.permitted_params
      ]
    end
  end
end
