# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class ApplicantInput < Common::Base
    include ActiveModel::Validations

    # Some branches have no end_date, but api requires it just the same
    validates :applicant_email, presence: true, format: /\A[a-zA-Z0-9_.+-]+@[a-zA-Z0-9_+-]+\.[a-zA-Z]+\z/
    validates :applicant_phone_number, presence: true, format: /\A[0-9+\s-]{0,20}\z/
    validates :applicant_relationship_to_claimant, inclusion: { in: ['self', 'Authorized Agent/Rep'] }
    validates :completing_reason, length: { maximum: 256 }, presence: true
    validates :mailing_address, :name, presence: true

    attribute :applicant_email, String
    attribute :applicant_phone_number, String
    attribute :applicant_relationship_to_claimant, String
    attribute :completing_reason, String
    attribute :mailing_address, AddressInput
    attribute :name, NameInput
  end
end
