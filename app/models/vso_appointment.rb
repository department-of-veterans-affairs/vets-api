# frozen_string_literal: true

class VsoAppointment
  extend ActiveModel::Callbacks

  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :veteranFullName, String
  attribute :veteranSSN, String
  attribute :vaFileNumber, String
  attribute :insuranceNumber, String
  attribute :claimantFullName, String
  attribute :claimantAddress, String
  attribute :claimantEmail, String
  attribute :claimantDaytimePhone, String
  attribute :claimantEveningPhone, String
  attribute :relationship, String
  attribute :appointmentDate, String
  attribute :organizationName, String
  attribute :organizationEmail, String
  attribute :organizationRepresentativeName, String
  attribute :organizationRepresentativeTitle, String
  attribute :disclosureExceptionDrugAbuse, Boolean
  attribute :disclosureExceptionAlcoholism, Boolean
  attribute :disclosureExceptionHIV, Boolean
  attribute :disclosureExceptionSickleCellAnemia, Boolean

  validates :veteranFullName, presence: true
  validates :veteranSSN, presence: true, format: /\A[\d]{3}-[\d]{2}-[\d]{4}\Z/
  validates :vaFileNumber, presence: true
  validates :insuranceNumber, presence: true
  validates :claimantFullName, presence: true
  validates :claimantAddress, presence: true
  validates :claimantEmail, presence: true
  validates :claimantDaytimePhone, presence: true
  validates :claimantEveningPhone, presence: true
  validates :relationship, presence: true
  validates :appointmentDate, presence: true, format: /\A[\d]{4}-[\d]{2}-[\d]{2}\Z/
  validates :organizationName, presence: true
  validates :organizationEmail, presence: true
  validates :organizationRepresentativeName, presence: true
  validates :organizationRepresentativeTitle, presence: true
end
