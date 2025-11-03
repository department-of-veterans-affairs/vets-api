# frozen_string_literal: true

require 'lighthouse/healthcare_cost_and_coverage/account/service'
require 'lighthouse/healthcare_cost_and_coverage/invoice/service'
require 'lighthouse/healthcare_cost_and_coverage/charge_item/service'

module MedicalCopays
  module Lighthouse
    class Service
      def initialize(icn)
        @icn = icn
      end

      def list
        invoice = invoice_service.list

        # invoices = invoice['entry'].map do |entry|
        #   ::Lighthouse::HCC::Invoice.new(entry)
        # end

        charge_item = charge_item_service.list

        charge_items = charge_item['entry'].map do |item|
          ::Lighthouse::HCC::ChargeItem.new(item)
        end


      end

      def count
        # Datadog stuff here?
        invoices = invoice_service.list
        invoice_count = invoices['total']
        invoice_count.blank? ? 0 : invoice_count # is this a legit scenario?
      rescue StandardError => e
        # Datadog stuff here?
        Rails.logger("MedicalCopays::Lighthouse::Service#count error: #{e.message}")
        raise e
      end

      def charge_item_service
        ::Lighthouse::HealthcareCostAndCoverage::ChargeItem::Service.new(@icn)
      end

      def invoice_service
        ::Lighthouse::HealthcareCostAndCoverage::Invoice::Service.new(@icn)
      end

      def account_service # may not need
        ::Lighthouse::HealthcareCostAndCoverage::Account::Service.new(@icn)
      end
    end
  end
end
