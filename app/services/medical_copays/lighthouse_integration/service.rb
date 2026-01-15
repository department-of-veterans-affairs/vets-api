# frozen_string_literal: true

require 'lighthouse/healthcare_cost_and_coverage/invoice/service'
require 'lighthouse/healthcare_cost_and_coverage/account/service'
require 'lighthouse/healthcare_cost_and_coverage/charge_item/service'
require 'lighthouse/healthcare_cost_and_coverage/encounter/service'
require 'lighthouse/healthcare_cost_and_coverage/medication_dispense/service'
require 'lighthouse/healthcare_cost_and_coverage/medication/service'
require 'lighthouse/healthcare_cost_and_coverage/payment_reconciliation/service'
require 'lighthouse/healthcare_cost_and_coverage/organization/service'
require 'concurrent-ruby'

module MedicalCopays
  module LighthouseIntegration
    class Service
      # Encounter API lacks _id filter; fetch all and filter client-side
      ENCOUNTER_FETCH_LIMIT = 200
      CHARGE_ITEM_FETCH_LIMIT = 100
      PAYMENT_FETCH_LIMIT = 100

      class MissingOrganizationIdError < StandardError; end
      class MissingCityError < StandardError; end

      def initialize(icn)
        @icn = icn
      end

      def list(count:, page:)
        raw_invoices = invoice_service.list(count:, page:)

        entries = raw_invoices.fetch('entry').map do |entry|
          resource = entry.fetch('resource')

          org_ref = resource.dig('issuer', 'reference').to_s
          parts = org_ref.split('/')

          org_id = parts.include?('Organization') ? parts.last : nil
          raise MissingOrganizationIdError, 'Missing org_id for invoice entry' if org_id.blank?

          org_city = retrieve_city(org_id)
          raise MissingCityError, "Missing city for org_id #{org_id}" if org_city.blank?

          enriched_resource = resource.merge('city' => org_city, 'facility_id' => org_id)
          enriched_entry = entry.merge('resource' => enriched_resource)

          Lighthouse::HCC::Invoice.new(enriched_entry)
        end

        Lighthouse::HCC::Bundle.new(raw_invoices, entries)
      rescue => e
        Rails.logger.error("MedicalCopays::LighthouseIntegration::Service#list error: #{e.class}: #{e.message}")
        raise
      end

      def get_detail(id:)
        invoice_data = invoice_service.read(id)

        invoice_deps = fetch_invoice_dependencies(invoice_data, id)
        charge_item_deps = fetch_charge_item_dependencies(invoice_deps[:charge_items])
        medications = fetch_medications(charge_item_deps[:medication_dispenses])

        Lighthouse::HCC::CopayDetail.new(
          invoice_data:,
          account_data: invoice_deps[:account],
          charge_items: invoice_deps[:charge_items],
          encounters: charge_item_deps[:encounters],
          medication_dispenses: charge_item_deps[:medication_dispenses],
          medications:,
          payments: invoice_deps[:payments]
        )
      rescue => e
        Rails.logger.error(
          "MedicalCopays::LighthouseIntegration::Service#get_detail error for invoice #{id}: #{e.message}"
        )
        raise e
      end

      private

      def retrieve_city(org_id)
        org_data = organization_service.read(org_id)
        org_data.dig('entry', 0, 'resource', 'address', 0, 'city')
      end

      def fetch_invoice_dependencies(invoice_data, invoice_id)
        account_future = Concurrent::Promises.future { fetch_account(invoice_data) }
        charge_items_future = Concurrent::Promises.future { fetch_charge_items(invoice_data) }
        payments_future = Concurrent::Promises.future { fetch_payments(invoice_id) }

        {
          account: account_future.value!,
          charge_items: charge_items_future.value!,
          payments: payments_future.value!
        }
      end

      def fetch_charge_item_dependencies(charge_items)
        encounters_future = Concurrent::Promises.future { fetch_encounters(charge_items) }
        medication_dispenses_future = Concurrent::Promises.future { fetch_medication_dispenses(charge_items) }

        {
          encounters: encounters_future.value!,
          medication_dispenses: medication_dispenses_future.value!
        }
      end

      def fetch_account(invoice_data)
        account_ref = invoice_data.dig('account', 'reference')
        return nil unless account_ref

        account_id = extract_id_from_reference(account_ref)
        return nil unless account_id

        response = account_service.list(id: account_id)
        response.dig('entry', 0, 'resource')
      rescue => e
        Rails.logger.warn { "Failed to fetch account #{account_id}: #{e.message}" }
        nil
      end

      def fetch_charge_items(invoice_data)
        charge_item_ids = extract_charge_item_ids(invoice_data)
        return {} if charge_item_ids.empty?

        response = charge_item_service.list(count: CHARGE_ITEM_FETCH_LIMIT)
        entries = response['entry'] || []
        entries.each_with_object({}) do |entry, hash|
          resource = entry['resource']
          hash[resource['id']] = resource if resource && charge_item_ids.include?(resource['id'])
        end
      rescue => e
        Rails.logger.warn { "Failed to fetch charge items: #{e.message}" }
        {}
      end

      def fetch_encounters(charge_items)
        encounter_ids = charge_items.values.filter_map do |ci|
          ref = ci.dig('context', 'reference')
          extract_id_from_reference(ref) if ref
        end
        return {} if encounter_ids.empty?

        response = encounter_service.list(count: ENCOUNTER_FETCH_LIMIT)
        entries = response['entry'] || []
        entries.each_with_object({}) do |entry, hash|
          resource = entry['resource']
          hash[resource['id']] = resource if resource && encounter_ids.include?(resource['id'])
        end
      rescue => e
        Rails.logger.warn { "Failed to fetch encounters: #{e.message}" }
        {}
      end

      def fetch_medication_dispenses(charge_items)
        dispense_ids = charge_items.values.flat_map do |ci|
          (ci['service'] || []).filter_map do |svc|
            ref = svc['reference']
            extract_id_from_reference(ref) if ref&.include?('MedicationDispense')
          end
        end

        fetch_and_index('medication dispenses', dispense_ids, medication_dispense_service)
      end

      def fetch_medications(medication_dispenses)
        medication_ids = medication_dispenses.values.filter_map do |md|
          ref = md.dig('medicationReference', 'reference')
          extract_id_from_reference(ref) if ref
        end

        fetch_and_index('medications', medication_ids, medication_service)
      end

      def fetch_and_index(data_type, ids, service)
        return {} if ids.empty?

        response = service.list(id: ids.join(','))
        entries = response['entry'] || []
        entries.each_with_object({}) do |entry, hash|
          resource = entry['resource']
          hash[resource['id']] = resource if resource && resource['id']
        end
      rescue => e
        Rails.logger.warn { "Failed to fetch #{data_type}: #{e.message}" }
        {}
      end

      def fetch_payments(invoice_id)
        response = payment_reconciliation_service.list(count: PAYMENT_FETCH_LIMIT)
        entries = response['entry'] || []

        entries.filter_map do |entry|
          resource = entry['resource']
          next unless resource

          invoice_ref = find_invoice_reference(resource)
          resource if invoice_ref == invoice_id
        end
      rescue => e
        Rails.logger.warn { "Failed to fetch payments: #{e.message}" }
        []
      end

      def find_invoice_reference(payment)
        extensions = payment['extension'] || []
        target_ext = extensions.find { |e| e['url']&.include?('allocation.target') }
        return nil unless target_ext

        ref = target_ext.dig('valueReference', 'reference')
        extract_id_from_reference(ref)
      end

      def extract_charge_item_ids(invoice_data)
        line_items = invoice_data['lineItem'] || []
        line_items.filter_map do |li|
          ref = li.dig('chargeItemReference', 'reference')
          extract_id_from_reference(ref) if ref
        end
      end

      def extract_id_from_reference(reference)
        return nil unless reference

        reference.split('/').last
      end

      def organization_service
        @organization_service ||= ::Lighthouse::HealthcareCostAndCoverage::Organization::Service.new(@icn)
      end

      def invoice_service
        @invoice_service ||= ::Lighthouse::HealthcareCostAndCoverage::Invoice::Service.new(@icn)
      end

      def account_service
        @account_service ||= ::Lighthouse::HealthcareCostAndCoverage::Account::Service.new(@icn)
      end

      def charge_item_service
        @charge_item_service ||= ::Lighthouse::HealthcareCostAndCoverage::ChargeItem::Service.new(@icn)
      end

      def encounter_service
        @encounter_service ||= ::Lighthouse::HealthcareCostAndCoverage::Encounter::Service.new(@icn)
      end

      def medication_dispense_service
        @medication_dispense_service ||= ::Lighthouse::HealthcareCostAndCoverage::MedicationDispense::Service.new(@icn)
      end

      def medication_service
        @medication_service ||= ::Lighthouse::HealthcareCostAndCoverage::Medication::Service.new(@icn)
      end

      def payment_reconciliation_service
        @payment_reconciliation_service ||= ::Lighthouse::HealthcareCostAndCoverage::PaymentReconciliation::Service.new(@icn)
      end
    end
  end
end
