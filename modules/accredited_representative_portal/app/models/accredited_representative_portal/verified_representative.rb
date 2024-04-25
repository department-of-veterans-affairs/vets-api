# frozen_string_literal: true

module AccreditedRepresentativePortal
  # Represents a verified representative within the Accredited Representative Portal.
  # This class is responsible for managing the data associated with individuals who have
  # been verified as representatives by the ARF Team. The model includes validations to ensure the presence and
  # uniqueness of identifiers such as the OGC registration number and email.
  #
  # Currently, this model is populated manually by engineers as users are accepted into the pilot program.
  # There is potential for a UI to be developed in the future that would facilitate administrative tasks
  # related to managing verified representatives.
  #
  # A more automated process may be possible once OGC and MPI data facilitate such a process.
  #
  # == Associations
  # This model may eventually be associated with AccreditedIndividuals to pull POA codes,
  # if they exist, based on the OGC registration number. It currently does so via a helper method.
  class VerifiedRepresentative < ApplicationRecord
    EMAIL_CONFLICT_ERROR_MESSAGE =
      'Conflict with multiple `AccreditedIndividuals` having the same email. ' \
      'Please review before attempting to add this `VerifiedRepresentative` record.'

    validates :ogc_registration_number, presence: true, uniqueness: { case_sensitive: false }
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    before_save :validate_unique_accredited_individual_email

    def validate_unique_accredited_individual_email
      individuals = AccreditedIndividual.where(email:)
      errors.add(:email, EMAIL_CONFLICT_ERROR_MESSAGE) if individuals.count > 1
    end

    # NOTE: given there will be RepresentativeUsers who are not VerifiedRepresentatives,
    # it's okay for this to return nil
    def poa_codes
      AccreditedIndividual.find_by(registration_number: ogc_registration_number)&.poa_codes
    end
  end
end
