# frozen_string_literal: true

require 'bgs_service/person_web_service'
require 'bgs_service/redis/find_poas_service'

module ClaimsApi
  class DependentClaimantVerificationService
    CLAIMANT_NOT_A_DEPENDENT_ERROR_MESSAGE = 'The claimant is not listed as a dependent for the specified Veteran. ' \
                                             'Please submit VA Form 21-686c to add this dependent.'
    POA_CODE_NOT_FOUND_ERROR_MESSAGE = 'The requested POA code could not be found.'

    attr_reader :claimant_participant_id, :claimant_ssn

    def initialize(**options)
      @veteran_participant_id = options[:veteran_participant_id]
      @claimant_first_name = options[:claimant_first_name]
      @claimant_last_name = options[:claimant_last_name]
      @claimant_participant_id = options[:claimant_participant_id]
      @claimant_ssn = nil
      @poa_code = options[:poa_code]
    end

    def validate_dependent_by_participant_id!
      return nil if valid_participant_dependent_combo?

      raise ::Common::Exceptions::UnprocessableEntity.new(detail: CLAIMANT_NOT_A_DEPENDENT_ERROR_MESSAGE)
    end

    def validate_poa_code_exists!
      return nil if poa_code_exists?

      raise ::Common::Exceptions::UnprocessableEntity.new(detail: POA_CODE_NOT_FOUND_ERROR_MESSAGE)
    end

    private

    def normalize(item)
      item.to_s.strip.upcase
    end

    def person_web_service
      ClaimsApi::PersonWebService.new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
    end

    def matching_participant_id?(dependent)
      return false unless normalize(@claimant_participant_id) == normalize(dependent[:ptcpnt_id])

      @claimant_ssn = dependent[:ssn_nbr]

      true
    end

    def any_matching_dependents?(dependents)
      Array.wrap(dependents).any? do |dependent|
        # If the claimant_participant_id is present (most v2), use it to verify the dependent
        return matching_participant_id?(dependent) if @claimant_participant_id.present?

        # Otherwise, we need to verify the dependent by first and last name (all v1 and some v2 without participant_ids)
        normalized_claimant_first_name = normalize(@claimant_first_name)
        normalized_claimant_last_name = normalize(@claimant_last_name)
        normalized_dependent_first_name = normalize(dependent[:first_nm])
        normalized_dependent_last_name = normalize(dependent[:last_nm])

        return false if [normalized_claimant_first_name, normalized_claimant_last_name,
                         normalized_dependent_first_name, normalized_dependent_last_name].any?(&:blank?)

        if normalized_claimant_first_name == normalized_dependent_first_name &&
           normalized_claimant_last_name == normalized_dependent_last_name
          @claimant_participant_id = dependent[:ptcpnt_id]
          @claimant_ssn = dependent[:ssn_nbr]

          return true
        end
      end
    end

    def valid_participant_dependent_combo?
      return false if @veteran_participant_id.blank?

      response = person_web_service.find_dependents_by_ptcpnt_id(@veteran_participant_id)

      return false if response.nil? || response.fetch(:number_of_records, 0).to_i.zero?

      dependents = response[:dependent]

      any_matching_dependents?(dependents)
    end

    def poa_code_exists?
      return false if @poa_code.blank?

      response = ClaimsApi::FindPOAsService.new.response

      return false if response.nil? || !response.is_a?(Array) || response.empty?

      response.any? do |poa_participant_pair|
        normalize(poa_participant_pair[:legacy_poa_cd]) == normalize(@poa_code) &&
          poa_participant_pair[:ptcpnt_id].present?
      end
    end
  end
end
