# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class ServiceRecord < Preneeds::Base
    attribute :service_branch, String
    attribute :discharge_type, String
    attribute :highest_rank, String
    attribute :national_guard_state, String

    attribute :date_range, Preneeds::DateRange

    def as_eoas
      hash = {
        branchOfService: service_branch, dischargeType: discharge_type,
        enteredOnDutyDate: date_range.try(:[], :from), highestRank: highest_rank,
        nationalGuardState: national_guard_state, releaseFromDutyDate: date_range.try(:[], :to)
      }

      %i[
enteredOnDutyDate releaseFromDutyDate highestRank 
nationalGuardState dischargeType].each do |key|
        hash.delete(key) if hash[key].blank?
      end

      hash
    end

    def self.permitted_params
      [
        :service_branch, :discharge_type, :highest_rank, :national_guard_state,
        date_range: Preneeds::DateRange.permitted_params
      ]
    end
  end
end
