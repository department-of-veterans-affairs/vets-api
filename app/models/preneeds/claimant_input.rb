# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class ClaimantInput < Common::Base
    include ActiveModel::Validations

    # Removed length validation on email for now: bad xsd validation
    validates :date_of_birth, format: { with: /\A\d{4}-\d{2}-\d{2}\z/ }
    validates :desired_cemetery, numericality: { only: :integer, greater_than: 0, less_than: 1000 }
    validates :email, format: { with: /\A[a-zA-Z0-9_.+-]+@[a-zA-Z0-9_+-]+\.[a-zA-Z]+\z/, allow_blank: true }
    validates :phone_number, format: { with: /\A[0-9+\s-]{0,20}\z/ }
    validates :relationship_to_vet, inclusion: { in: %w(1 2 3) }
    validates :address, :name, presence: true
    validates :ssn, format: { with: /\A\d{3}-\d{2}-\d{4}\z/ }

    attribute :address, AddressInput
    attribute :date_of_birth, XmlDate
    attribute :desired_cemetery, Integer
    attribute :email, String
    attribute :name, NameInput
    attribute :phone_number, String
    attribute :relationship_to_vet, String
    attribute :ssn, String
  end
end
