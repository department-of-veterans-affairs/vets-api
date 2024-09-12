# frozen_string_literal: true

require 'bgs_service/person_web_service'

module ClaimsApi
  module DependentClaimantVerification
    extend ActiveSupport::Concern

    included do
      def validate_dependent_by_participant_id!(participant_id, dependent_first_name, dependent_last_name)
        return if valid_participant_dependent_combo?(participant_id, dependent_first_name, dependent_last_name)

        raise ::Common::Exceptions::InvalidFieldValue.new('participant_id: dependent combo',
                                                          "#{participant_id}: #{dependent_first_name} " \
                                                          "#{dependent_last_name}")
      end
    end

    private

    def normalize_name(name)
      return '' unless name

      name.strip.upcase
    end

    def valid_participant_dependent_combo?(participant_id, dependent_first_name, dependent_last_name)
      return false if participant_id.blank?

      person_web_service = PersonWebService.new(external_uid: 'dependent_claimant_verification_uid',
                                                external_key: 'dependent_claimant_verification_key')
      dependents = person_web_service.find_dependents_by_ptcpnt_id(participant_id)

      return false if dependents.nil? || dependents[:number_of_records].to_i.zero?

      Array.wrap(dependents).any? do |dependent|
        normalized_first_name = normalize_name(dependent_first_name)
        normalized_last_name = normalize_name(dependent_last_name)
        dependent_first_name_normalized = normalize_name(dependent[:dependent][:first_nm])
        dependent_last_name_normalized = normalize_name(dependent[:dependent][:last_nm])

        return false if [normalized_first_name, normalized_last_name, dependent_first_name_normalized,
                         dependent_last_name_normalized].any?(&:blank?)

        normalized_first_name == dependent_first_name_normalized &&
          normalized_last_name == dependent_last_name_normalized
      end
    end
  end
end
