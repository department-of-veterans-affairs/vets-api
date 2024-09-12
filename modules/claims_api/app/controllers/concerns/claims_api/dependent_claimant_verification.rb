# frozen_string_literal: true

require 'bgs_service/person_web_service'

module ClaimsApi
  module DependentClaimantVerification
    extend ActiveSupport::Concern

    included do
      def validate_dependent_by_participant_id!(participant_id, dependent_first_name, dependent_last_name)
        return if valid_participant_dependent_combo?(participant_id, dependent_first_name, dependent_last_name)

        detail = 'The claimant is not listed as a dependent for the specified Veteran. Please submit VA Form 21-686c ' \
                 'to add this dependent.'
        raise ::Common::Exceptions::UnprocessableEntity.new(detail:)
      end
    end

    private

    def normalize_name(name)
      name.to_s.strip.upcase
    end

    def valid_participant_dependent_combo?(participant_id, dependent_first_name_to_verify,
                                           dependent_last_name_to_verify)
      return false if participant_id.blank?

      person_web_service = PersonWebService.new(external_uid: 'dependent_claimant_verification_uid',
                                                external_key: 'dependent_claimant_verification_key')
      response = person_web_service.find_dependents_by_ptcpnt_id(participant_id)

      return false if response.nil? || response.fetch(:number_of_records, 0).to_i.zero?

      dependents = response[:dependent]

      Array.wrap(dependents).any? do |dependent|
        normalized_first_name_to_verify = normalize_name(dependent_first_name_to_verify)
        normalized_last_name_to_verify = normalize_name(dependent_last_name_to_verify)
        normalized_first_name_service = normalize_name(dependent[:first_nm])
        normalized_last_name_service = normalize_name(dependent[:last_nm])

        return false if [normalized_first_name_to_verify, normalized_last_name_to_verify, normalized_first_name_service,
                         normalized_last_name_service].any?(&:blank?)

        normalized_first_name_to_verify == normalized_first_name_service &&
          normalized_last_name_to_verify == normalized_last_name_service
      end
    end
  end
end
