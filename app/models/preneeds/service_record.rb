# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class ServiceRecord < Preneeds::Base
    attribute :branch_of_service, String
    attribute :discharge_type, String
    attribute :entered_on_duty_date, XmlDate
    attribute :highest_rank, String
    attribute :national_guard_state, String
    attribute :release_from_duty_date, XmlDate

    def message
      hash = {
        branchOfService: branch_of_service, dischargeType: discharge_type,
        enteredOnDutyDate: entered_on_duty_date, highestRank: highest_rank,
        nationalGuardState: national_guard_state, releaseFromDutyDate: release_from_duty_date
      }

      [:enteredOnDutyDate, :releaseFromDutyDate, :highestRank, :nationalGuardState].each do |key|
        hash.delete(key) if hash[key].nil?
      end
      hash
    end

    def self.permitted_params
      [
        :branch_of_service, :discharge_type, :entered_on_duty_date,
        :highest_rank, :national_guard_state, :release_from_duty_date
      ]
    end
  end
end
