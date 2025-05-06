# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Observation
        def self.parse(diagnostic_report_info)
          diagnostic_report_info.deep_symbolize_keys!
          Mobile::V0::Observation.new(
            id: diagnostic_report_info[:id],
            status: diagnostic_report_info[:status],
            category: diagnostic_report_info[:category],
            code: diagnostic_report_info[:code],
            subject: diagnostic_report_info[:subject],
            effectiveDateTime: diagnostic_report_info[:effectiveDateTime],
            issued: diagnostic_report_info[:issued],
            performer: diagnostic_report_info[:performer],
            valueQuantity: diagnostic_report_info[:valueQuantity]
          )
        end
      end
    end
  end
end
