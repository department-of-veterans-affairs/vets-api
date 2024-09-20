# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models service record information for a {Preneeds::BurialForm} form
  #
  # @!attribute service_branch
  #   @return (see Preneeds::BranchesOfService#code)
  # @!attribute discharge_type
  #   @return (see Preneeds::DischargeType#id)
  # @!attribute highest_rank
  #   @return [String] highest rank achieved
  # @!attribute national_guard_state
  #   @return [String] state - for national guard service only
  # @!attribute date_range
  #   @return [Preneeds::DateRange] service date range
  #
  class ServiceRecord < Preneeds::Base
    attr_accessor :service_branch,
                  :discharge_type,
                  :highest_rank,
                  :national_guard_state,
                  :date_range

    def initialize(attributes = {})
      super
      @date_range = Preneeds::DateRange.new(attributes[:date_range])
    end

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      hash = {
        branchOfService: service_branch, dischargeType: discharge_type,
        enteredOnDutyDate: date_range.try(:[], :from), highestRank: highest_rank,
        nationalGuardState: national_guard_state, releaseFromDutyDate: date_range.try(:[], :to)
      }

      %i[
        enteredOnDutyDate releaseFromDutyDate highestRank nationalGuardState dischargeType
      ].each do |key|
        hash.delete(key) if hash[key].blank?
      end

      hash
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      [
        :service_branch, :discharge_type, :highest_rank, :national_guard_state,
        { date_range: Preneeds::DateRange.permitted_params }
      ]
    end
  end
end
