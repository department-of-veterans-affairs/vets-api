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
    EMAIL_NO_MATCH_MESSAGE = 'No matching email for AccreditedIndividual found for VerifiedRepresentative'
    EMAIL_MULTIPLE_MATCH_MESSAGE =
      'Multiple `AccreditedIndividuals` have the same email. Please review.'

    validates :ogc_registration_number, presence: true, uniqueness: { case_sensitive: false }
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    before_save :handle_email_uniqueness

    # Fetches Power of Attorney (POA) codes based on the representative's registration number.
    # This method performs checks on the uniqueness of the representative's email
    # and the existence of a corresponding AccreditedIndividual.
    #
    # It handles potential errors in data retrieval gracefully by logging any exceptions
    # and returning nil in such cases.
    #
    # @return [Array<String>, nil] the POA codes if found and valid; otherwise, nil if:
    #   - no AccreditedIndividual matches the provided registration number,
    #   - an exception occurs during data retrieval.
    def poa_codes
      handle_email_uniqueness
      fetch_poa_codes
    rescue => e
      log_fetch_failure(e)
      nil
    end

    private

    # TODO: change this to a validation that returns error messages when a more automated approach is implemented
    # See discussion: https://github.com/department-of-veterans-affairs/vets-api/pull/16493/files#r1579523634
    def handle_email_uniqueness
      Rails.logger.info(EMAIL_NO_MATCH_MESSAGE) if accredited_individual_email_count.zero?
      log_accredited_individual_multiple_email_match if accredited_individual_email_count > 1
    end

    # Fetches the Power of Attorney (POA) codes from an AccreditedIndividual based on the OGC registration number.
    # Logs and handles cases where no AccreditedIndividual or no POA codes are found.
    #
    # @return [Array<String>, nil] The POA codes if available, or nil if not found or if no codes exist.
    def fetch_poa_codes
      accredited_individual = AccreditedIndividual.find_by(registration_number: ogc_registration_number)

      if accredited_individual&.poa_codes.present?
        accredited_individual.poa_codes
      else
        log_accredited_individual_missing_data(accredited_individual)
        nil
      end
    end

    def log_accredited_individual_missing_data(accredited_individual)
      if accredited_individual.nil?
        Rails.logger.info("No matching AccreditedIndividual found for VerifiedRepresentative ID: #{id}")
      else
        Rails.logger.info("No matching POA codes for VerifiedRepresentative ID: #{id}")
      end
    end

    def log_accredited_individual_multiple_email_match
      message = "#{EMAIL_MULTIPLE_MATCH_MESSAGE} AccreditedIndividual IDs: #{fetch_accredited_individual_ids}"
      message += " VerifiedRepresentative ID: #{id}" unless new_record?
      Rails.logger.info(message)
    end

    def fetch_accredited_individual_ids
      AccreditedIndividual.where(email:).pluck(:id).join(', ')
    end

    def log_fetch_failure(exception)
      Rails.logger.info("Fetching POA codes failed for VerifiedRepresentative ID: #{id} - #{exception.message}")
    end

    def accredited_individual_email_count
      @accredited_individual_email_count ||= AccreditedIndividual.where(email:).count
    end
  end
end
