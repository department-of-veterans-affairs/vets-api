# frozen_string_literal: true

require 'lighthouse/healthcare_cost_and_coverage/invoice/service'

module MedicalCopays
  module LighthouseIntegration
    class Service
      def initialize(icn)
        @icn = icn
      end

      def list(count:, page:)
        raw_invoices = invoice_service.list(count:, page:)
        entries = raw_invoices['entry'].map do |entry|
          Lighthouse::HCC::Invoice.new(entry)
        end

        Lighthouse::HCC::Bundle.new(raw_invoices, entries)
      rescue => e
        Rails.logger.error("MedicalCopays::Lighthouse::Service#list error: #{e.message}")
        raise e
      end

      def invoice_service
        ::Lighthouse::HealthcareCostAndCoverage::Invoice::Service.new(@icn)
      end
    end
  end
end
