# frozen_string_literal: true

module DependentsBenefits
  ##
  # Serializer for dependent information retrieved from BGS.
  # Combines person data with dependency decisions (diaries) to provide
  # information about benefit eligibility, upcoming removals, and benefit types.
  #
  # Uses JSONAPI::Serializer for JSON API compliant output.
  #
  class DependentsSerializer
    extend DependentsHelper
    include JSONAPI::Serializer

    set_id { '' }
    set_type :dependents

    ##
    # Serializes person records with enriched dependency information.
    # Handles both single person (Hash) and multiple persons (Array) inputs.
    # Enriches each person with:
    # - upcoming_removal_date: When the person's benefits will end
    # - upcoming_removal_reason: Why the benefits will end (e.g., "Turns 18")
    # - dependent_benefit_type: The type of benefit currently received
    #
    # @return [Array<Hash>] Array of person records with dependency information
    #
    attribute :persons do |object|
      next [object[:persons]] if object[:persons].instance_of?(Hash)

      arr = object[:persons]
      diaries = object[:diaries]

      next arr if dependency_decisions(diaries).blank?

      decisions = current_and_pending_decisions(diaries)

      arr.each do |person|
        upcoming_removal = person[:upcoming_removal] = upcoming_removals(decisions)[person[:ptcpnt_id]]
        if upcoming_removal
          person[:upcoming_removal_date] = parse_time(upcoming_removal[:award_effective_date])
          person[:upcoming_removal_reason] = trim_whitespace(upcoming_removal[:dependency_decision_type_description])
        end

        person[:dependent_benefit_type] = dependent_benefit_types(decisions)[person[:ptcpnt_id]]
      end
    end
  end
end
