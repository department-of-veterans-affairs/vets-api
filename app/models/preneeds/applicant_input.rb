# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class ApplicantInput < Common::Base
    include ActiveModel::Validations

    validate :validate_name, if: -> (v) { v.name.present? }
    validate :validate_mailing_address, if: -> (v) { v.mailing_address.present? }

    # TODO: email < 20 bad xsd
    validates :applicant_email, format: { with: /\A[a-zA-Z0-9_.+-]+@[a-zA-Z0-9_+-]+\.[a-zA-Z]+\z/ }
    validates :applicant_phone_number, format: { with: /\A[0-9+\s-]{0,20}\z/ }, presence: true
    validates :applicant_relationship_to_claimant, inclusion: { in: ['Self', 'Authorized Agent/Rep'] }
    validates :completing_reason, length: { maximum: 256 }, presence: true
    validates :mailing_address, :name, presence: true

    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String
    attribute :mailing_address, AddressInput
    attribute :name, NameInput

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
        mailing_address: AddressInput.permitted_params, name: NameInput.permitted_params
      ]
    end

    private

    def validate_name
      errors.add(:name, name.errors.full_messages.join(', ')) unless name.valid?
    end

    def validate_mailing_address
      errors.add(:mailing_address, mailing_address.errors.full_messages.join(', ')) unless mailing_address.valid?
    end
  end
end
