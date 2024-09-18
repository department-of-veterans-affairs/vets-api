# frozen_string_literal: true

require 'bgs_service/person_web_service'
require 'bgs_service/redis/find_poas_service'

module ClaimsApi
  class DependentClaimantVerificationService
    def initialize(participant_id, dependent_first_name, dependent_last_name, poa_code)
      @participant_id = participant_id
      @dependent_first_name = dependent_first_name
      @dependent_last_name = dependent_last_name
      @poa_code = poa_code
    end

    def validate_dependent_by_participant_id!
      return if valid_participant_dependent_combo?

      detail = 'The claimant is not listed as a dependent for the specified Veteran. Please submit VA Form 21-686c ' \
               'to add this dependent.'
      raise ::Common::Exceptions::UnprocessableEntity.new(detail:)
    end

    def validate_poa_code_exists!
      return if poa_code_exists?

      raise ::Common::Exceptions::UnprocessableEntity.new(detail: 'The requested POA code could not be found.')
    end

    private

    def normalize(item)
      item.to_s.strip.upcase
    end

    def valid_participant_dependent_combo?
      return false if @participant_id.blank?

      person_web_service = PersonWebService.new(external_uid: 'dependent_claimant_verification_uid',
                                                external_key: 'dependent_claimant_verification_key')
      response = person_web_service.find_dependents_by_ptcpnt_id(@participant_id)

      return false if response.nil? || response.fetch(:number_of_records, 0).to_i.zero?

      dependents = response[:dependent]

      Array.wrap(dependents).any? do |dependent|
        normalized_first_name_to_verify = normalize(@dependent_first_name)
        normalized_last_name_to_verify = normalize(@dependent_last_name)
        normalized_first_name_service = normalize(dependent[:first_nm])
        normalized_last_name_service = normalize(dependent[:last_nm])

        return false if [normalized_first_name_to_verify, normalized_last_name_to_verify, normalized_first_name_service,
                         normalized_last_name_service].any?(&:blank?)

        normalized_first_name_to_verify == normalized_first_name_service &&
          normalized_last_name_to_verify == normalized_last_name_service
      end
    end

    def poa_code_exists?
      return false if @poa_code.blank?

      response = FindPOAsService.new.response

      return false if response.nil? || !response.is_a?(Array) || response.empty?

      response.any? do |poa_participant_pair|
        normalize(poa_participant_pair[:legacy_poa_cd]) == normalize(@poa_code) &&
          poa_participant_pair[:ptcpnt_id].present?
      end
    end
  end
end
