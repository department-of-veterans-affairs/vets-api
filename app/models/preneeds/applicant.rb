# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class Applicant < Common::Base
    include ActiveModel::Validations

    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String

    attribute :mailing_address, Preneeds::Address
    attribute :name, Preneeds::Name

    validates :applicant_email, format: { with: /\A[a-zA-Z0-9_.+-]+@[a-zA-Z0-9_+-]+\.[a-zA-Z]+\z/ }
    validates :applicant_phone_number, format: { with: /\A[0-9+\s-]{0,20}\z/ }, presence: true
    validates :applicant_relationship_to_claimant, inclusion: { in: ['Self', 'Authorized Agent/Rep'] }
    validates :completing_reason, length: { maximum: 256 }, presence: true

    validates :name, :mailing_address, presence: true, preneeds_embedded_object: true

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      {
        applicant_email: applicant_email, applicant_phone_number: applicant_phone_number,
        applicant_relationship_to_claimant: applicant_relationship_to_claimant,
        completing_reason: completing_reason, mailing_address: mailing_address.message,
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
