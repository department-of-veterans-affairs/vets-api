# frozen_string_literal: true

require 'lighthouse/healthcare_cost_and_coverage/invoice/service'
require 'lighthouse/healthcare_cost_and_coverage/account/service'
require 'lighthouse/healthcare_cost_and_coverage/charge_item/service'
require 'lighthouse/healthcare_cost_and_coverage/encounter/service'
require 'lighthouse/healthcare_cost_and_coverage/medication_dispense/service'
require 'lighthouse/healthcare_cost_and_coverage/medication/service'
require 'lighthouse/healthcare_cost_and_coverage/payment_reconciliation/service'
require 'lighthouse/healthcare_cost_and_coverage/organization/service'
require 'lighthouse/healthcare_cost_and_coverage/patient/service'
require 'concurrent-ruby'

module MedicalCopays
  module LighthouseIntegration
    class Service
      # Encounter API lacks _id filter; fetch all and filter client-side
      ENCOUNTER_FETCH_LIMIT = 200
      CHARGE_ITEM_FETCH_LIMIT = 100
      PAYMENT_FETCH_LIMIT = 100
      STATSD_KEY_PREFIX = 'api.mcp.lighthouse'
      MAX_SUMMARY_PAGES = 20
      DEFAULT_MONTH_COUNT = 6
      DEFAULT_INVOICE_COUNT = 50

      class MissingOrganizationIdError < StandardError; end
      class MissingOrganizationRefError < StandardError; end
      class MissingCityError < StandardError; end
      class ServiceError < StandardError; end

      def initialize(icn)
        @icn = icn
      end

      def list(count:, page:)
        StatsD.increment("#{STATSD_KEY_PREFIX}.list.initiated")

        record_success('list') do
          raw_invoices = invoice_service.list(count:, page:)
          entries = build_invoice_entries(raw_invoices)
          Lighthouse::HCC::Bundle.new(raw_invoices, entries)
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.list.failure")
        Rails.logger.error("MedicalCopays::LighthouseIntegration::Service#list error: #{e.class}")
        raise
      end

      def summary(month_count: 6)
        result = collect_invoices_in_range(month_count)
        entries = result['entries']

        total_amount = 0.to_d
        count = 0

        entries.each do |entry|
          invoice = Lighthouse::HCC::Invoice.new(entry)
          total_amount += invoice.current_balance.to_d
          count += 1
        end

        summary_output(total_amount, count, month_count)
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.summary.failure")
        Rails.logger.error("MedicalCopays::LighthouseIntegration::Service#summary error: #{e.class}: #{e.message}")
        raise ServiceError, 'External service error'
      end

      def list_months(month_count: 6)
        result = collect_invoices_in_range(month_count)
        raw_bundle = result['raw_bundle']
        filtered_entries = result['entries']

        new_bundle = raw_bundle.merge(
          'entry' => filtered_entries,
          'total' => filtered_entries.length,
          'link' => []
        )

        formatted_entries = filtered_entries.empty? ? [] : build_invoice_entries(new_bundle)

        Lighthouse::HCC::Bundle.new(new_bundle, formatted_entries)
      end

      def get_detail(id:)
        StatsD.increment("#{STATSD_KEY_PREFIX}.detail.initiated")

        record_success('detail') do
          build_copay_detail(id)
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.detail.failure")
        Rails.logger.error(
          "MedicalCopays::LighthouseIntegration::Service#get_detail error for invoice #{id}: #{e.class}"
        )
        raise e
      end

      private

      # rubocop:disable Metrics/MethodLength
      def collect_invoices_in_range(month_count, count = 50)
        from = month_count.months.ago.utc
        page = 1
        collected_entries = []
        last_raw_bundle = nil

        loop do
          break if page > MAX_SUMMARY_PAGES

          raw = invoice_service.list(count:, page:)
          last_raw_bundle = raw

          entries = raw['entry'] || []
          break if entries.empty?

          entries.each do |entry|
            date_str = entry.dig('resource', 'date')
            next unless date_str

            invoice_date = Time.iso8601(date_str)

            next if invoice_date < from

            collected_entries << entry
          end

          page += 1
        end

        collected_entries.sort_by! { |entry| entry.dig('resource', 'date') }.reverse!

        {
          'raw_bundle' => last_raw_bundle,
          'entries' => collected_entries
        }
      end

      def build_copay_detail(id)
        invoice_data = invoice_service.read(id)

        patient_future = Concurrent::Promises.future { fetch_patient_data }
        invoice_deps = fetch_invoice_dependencies(invoice_data, id)
        org_id = extract_org_id_from_invoice(invoice_data, optional_org_data: true)
        org_address = retrieve_organization_address(org_id)
        patient_data = patient_future.value!
        associated_statements = invoices_for_organization(DEFAULT_MONTH_COUNT, DEFAULT_INVOICE_COUNT, org_id, id)

        charge_item_deps = fetch_charge_item_dependencies(invoice_deps[:charge_items])
        medications = fetch_medications(charge_item_deps[:medication_dispenses])

        Lighthouse::HCC::CopayDetail.new(
          invoice_data:,
          account_data: invoice_deps[:account],
          charge_items: invoice_deps[:charge_items],
          encounters: charge_item_deps[:encounters],
          associated_statements:,
          medication_dispenses: charge_item_deps[:medication_dispenses],
          medications:,
          payments: invoice_deps[:payments],
          facility_address: org_address,
          patient_data:
        )
      end
      # rubocop:enable Metrics/MethodLength

      def invoices_for_organization(month_count, count, organization_id, current_invoice_id)
        result = collect_invoices_in_range(month_count, count)

        filtered = result['entries'].select do |entry|
          next if entry.dig('resource', 'id') == current_invoice_id # do not return the current invoice data

          issuer_ref = entry.dig('resource', 'issuer', 'reference')
          entry_org_id = issuer_ref.split('/').last
          entry_org_id == organization_id
        end

        filtered.sort_by { |entry| entry.dig('resource', 'date') }.reverse
      end

      def build_invoice_entries(raw_invoices)
        raw_invoices.fetch('entry').map do |entry|
          resource = entry.fetch('resource')

          org_ref = resource.dig('issuer', 'reference').to_s
          parts = org_ref.split('/')

          org_id = parts.include?('Organization') ? parts.last : nil
          raise MissingOrganizationIdError, 'Missing org_id for invoice entry' if org_id.blank?

          org_address = retrieve_organization_address(org_id)
          org_city = org_address[:city] if org_address
          raise MissingCityError, "Missing city for org_id #{org_id}" if org_city.blank?

          enriched_resource = resource.merge('city' => org_city, 'facility_id' => org_id)
          enriched_entry = entry.merge('resource' => enriched_resource)

          Lighthouse::HCC::Invoice.new(enriched_entry)
        end
      end

      def retrieve_organization_address(org_id)
        return nil if org_id.blank?

        address = Rails.cache.fetch("lighthouse:org:#{org_id}:address", expires_in: 24.hours) do
          org_data = organization_service.read(org_id)
          org_data.dig('entry', 0, 'resource', 'address', 0)
        end

        return nil unless address

        {
          address_line1: address.dig('line', 0),
          address_line2: address.dig('line', 1),
          address_line3: address.dig('line', 2),
          city: address['city'],
          state: address['state'],
          postalCode: address['postalCode']
        }
      rescue => e
        Rails.logger.error { "Failed to fetch organization address: #{e.class}" }
        raise e
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
        Rails.logger.warn { "Failed to fetch account #{account_id}: #{e.class}" }
        nil
      end

      def fetch_patient_data
        patient_service.read(@icn)
      rescue => e
        Rails.logger.warn { "Failed to fetch patient data: #{e.class}" }
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
        Rails.logger.warn { "Failed to fetch charge items: #{e.class}" }
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
        Rails.logger.warn { "Failed to fetch encounters: #{e.class}" }
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
        Rails.logger.warn { "Failed to fetch #{data_type}: #{e.class}" }
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
        Rails.logger.warn { "Failed to fetch payments: #{e.class}" }
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

      def extract_org_id_from_invoice(invoice_data, optional_org_data: false)
        org_ref = invoice_data.dig('issuer', 'reference')
        return nil if optional_org_data && org_ref.blank? # how do we feel about this?

        raise MissingOrganizationRefError, 'No organization reference found' unless org_ref

        org_id = org_ref.split('/').last
        raise MissingOrganizationIdError, 'No organization ID found' unless org_id

        org_id
      end

      def process_entries(entries, from, total_amount, count)
        entries.each do |entry|
          date_str = entry.dig('resource', 'date')
          next unless date_str

          invoice_date = Time.iso8601(date_str)
          return [true, total_amount, count] if invoice_date < from

          invoice = Lighthouse::HCC::Invoice.new(entry)
          total_amount += invoice.current_balance.to_d
          count += 1
        end

        [false, total_amount, count]
      end

      def summary_output(total_amount, count, month_count)
        {
          entries: [],
          meta: {
            total_amount_due: total_amount.to_f,
            total_copays: count,
            month_window: month_count
          }
        }
      end

      def record_success(operation)
        start_time = Time.current
        result = yield
        StatsD.measure("#{STATSD_KEY_PREFIX}.#{operation}.latency", (Time.current - start_time) * 1000)
        StatsD.increment("#{STATSD_KEY_PREFIX}.#{operation}.success")
        result
      end

      def organization_service
        @organization_service ||= ::Lighthouse::HealthcareCostAndCoverage::Organization::Service.new(@icn)
      end

      def patient_service
        @patient_service ||= ::Lighthouse::HealthcareCostAndCoverage::Patient::Service.new(@icn)
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
