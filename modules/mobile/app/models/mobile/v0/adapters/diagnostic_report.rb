# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class DiagnosticReport
        include Mobile::Engine.routes.url_helpers

        def parse(diagnostic_report_info)
          Mobile::V0::DiagnosticReport.new(
            id: diagnostic_report_info['id'],
            category: diagnostic_report_info['category'].last['text'],
            code: diagnostic_report_info['code']['text'],
            subject: diagnostic_report_info['subject'],
            effectiveDateTime: diagnostic_report_info['effectiveDateTime'],
            issued: diagnostic_report_info['issued'],
            result: parse_results(diagnostic_report_info['result'])
          )
        end

        private

        def parse_results(results)
          results.each do |result|
            result['reference'] = Mobile::UrlHelper.new.v0_observation_url(result['reference'].split('/').last)
          end

          results
        end
      end
    end
  end
end
