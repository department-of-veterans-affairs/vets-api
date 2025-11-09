# frozen_string_literal: true

require 'lighthouse/healthcare_cost_and_coverage/account/service'
require 'lighthouse/healthcare_cost_and_coverage/invoice/service'
require 'lighthouse/healthcare_cost_and_coverage/charge_item/service'

module MedicalCopays
  module LighthouseIntegration
    class Service
      def initialize(icn)
        @icn = icn
      end

      def list(count:, page:)
        # Datadog stuff
        raw_invoices = invoice_service.list(count:, page:)
        entries = raw_invoices['entry'].map do |entry|
          ::Lighthouse::HCC::Invoice.new(entry)
        end

        Lighthouse::HCC::Bundle.new(raw_invoices, entries)
      rescue => e
        # Datadog stuff here?
        Rails.logger.error("MedicalCopays::Lighthouse::Service#list error: #{e.message}")
        raise e
      end

      def invoice_service
        ::Lighthouse::HealthcareCostAndCoverage::Invoice::Service.new(@icn)
      end

      # def charge_item_service
      #   ::Lighthouse::HealthcareCostAndCoverage::ChargeItem::Service.new(@icn)
      # end
      #
      # # may not need
      # def account_service
      #   ::Lighthouse::HealthcareCostAndCoverage::Account::Service.new(@icn)
      # end
    end
  end
end
