# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'

# rubocop:disable Metrics/ClassLength
module Veteran
  class VSOReloader < BaseReloader
    include Sidekiq::Job
    include Vets::SharedLogging

    # The total number of representatives and organizations parsed from the ingested .ASP files
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed

    # User type constants
    USER_TYPE_ATTORNEY = 'attorney'
    USER_TYPE_CLAIM_AGENT = 'claim_agents'
    USER_TYPE_VSO = 'veteran_service_officer'

    def perform
      setup_ingestion
      array_of_organizations = reload_representatives
      save_accreditation_totals
      remove_obsolete_representatives(array_of_organizations)
      complete_ingestion_log
    rescue Faraday::ConnectionFailed => e
      handle_connection_failure(e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      handle_client_error(e)
    end

    # Reloads attorney data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_attorneys
      reload_representative_type(
        endpoint: 'attorneyexcellist.asp',
        rep_type: :attorneys,
        user_type: USER_TYPE_ATTORNEY,
        processor: method(:find_or_create_attorneys)
      )
    end

    # Reloads claim agent data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_claim_agents
      reload_representative_type(
        endpoint: 'caexcellist.asp',
        rep_type: :claims_agents,
        user_type: USER_TYPE_CLAIM_AGENT,
        processor: method(:find_or_create_claim_agents)
      )
    end

    # Reloads VSO representative and organization data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_vso_reps
      mark_vso_entities_running
      ensure_initial_counts
      vso_data = fetch_data('orgsexcellist.asp')
      counts = calculate_vso_counts(vso_data)

      # Validate both counts - if either fails, skip processing both to maintain data integrity
      reps_valid = valid_count?(:vso_representatives, counts[:reps])
      orgs_valid = valid_count?(:vso_organizations, counts[:orgs])

      if reps_valid && orgs_valid
        process_valid_vso_data(vso_data, counts)
      else
        handle_vso_validation_failure(reps_valid, orgs_valid, counts)
      end
    rescue => e
      mark_vso_entities_failed(e.message)
      raise
    end

    # Common method for reloading attorney and claim agent data
    # @param endpoint [String] OGC endpoint to fetch data from
    # @param rep_type [Symbol] Type of representative for validation (:attorneys, :claims_agents)
    # @param user_type [String] Database user type constant
    # @param processor [Method] Method to process each record
    # @return [Array<String>] Representative IDs - either newly processed IDs or existing IDs if validation fails
    def reload_representative_type(endpoint:, rep_type:, user_type:, processor:)
      entity_type = map_rep_type_to_entity_type(rep_type)
      @ingestion_log&.mark_entity_running!(entity_type)
      ensure_initial_counts

      data = fetch_data(endpoint)
      new_count = data.count { |record| record['Registration Num'].present? }

      if valid_count?(rep_type, new_count)
        process_valid_representative_data(data, processor, entity_type, new_count)
      else
        handle_representative_validation_failure(entity_type, rep_type, user_type, new_count)
      end
    rescue => e
      @ingestion_log&.mark_entity_failed!(entity_type, error: e.message)
      raise
    end

    private

    def normalize_poa(poa)
      poa&.gsub(/\W/, '')
    end

    # Setup methods for perform

    def setup_ingestion
      @ingestion_log = RepresentationManagement::AccreditationDataIngestionLog.start_ingestion!(
        dataset: :trexler_file
      )
      @initial_counts = fetch_initial_counts
      @validation_results = {}
    end

    def remove_obsolete_representatives(array_of_organizations)
      Veteran::Service::Representative.where.not(representative_id: array_of_organizations).find_each do |rep|
        next if test_user?(rep)

        rep.destroy!
      end
    end

    def test_user?(rep)
      (rep.first_name == 'Tamara' && rep.last_name == 'Ellis') ||
        (rep.first_name == 'John' && rep.last_name == 'Doe')
    end

    def handle_connection_failure(error)
      log_message_to_sentry("OGC connection failed: #{error.message}", :warn)
      log_to_slack('VSO Reloader failed to connect to OGC')
      fail_ingestion_log("OGC connection failed: #{error.message}")
    end

    def handle_client_error(error)
      log_message_to_sentry("VSO Reloading error: #{error.message}", :warn)
      log_to_slack('VSO Reloader job has failed!')
      fail_ingestion_log("VSO Reloading error: #{error.message}")
    end

    # VSO-specific helper methods

    def mark_vso_entities_running
      @ingestion_log&.mark_entity_running!(:representatives)
      @ingestion_log&.mark_entity_running!(:veteran_service_organizations)
    end

    def mark_vso_entities_failed(error_message)
      @ingestion_log&.mark_entity_failed!(:representatives, error: error_message)
      @ingestion_log&.mark_entity_failed!(:veteran_service_organizations, error: error_message)
    end

    def process_valid_vso_data(vso_data, counts)
      result = process_vso_data(vso_data)
      @ingestion_log&.mark_entity_success!(:representatives, count: counts[:reps])
      @ingestion_log&.mark_entity_success!(:veteran_service_organizations, count: counts[:orgs])
      result
    end

    def handle_vso_validation_failure(reps_valid, orgs_valid, counts)
      mark_representatives_failed(counts) unless reps_valid
      mark_organizations_failed(counts) unless orgs_valid
      existing_vso_representative_ids
    end

    def mark_representatives_failed(counts)
      @ingestion_log&.mark_entity_failed!(
        :representatives,
        error: 'Count validation failed',
        count: counts[:reps],
        previous_count: get_previous_count(:vso_representatives)
      )
    end

    def mark_organizations_failed(counts)
      @ingestion_log&.mark_entity_failed!(
        :veteran_service_organizations,
        error: 'Count validation failed',
        count: counts[:orgs],
        previous_count: get_previous_count(:vso_organizations)
      )
    end

    def existing_vso_representative_ids
      Veteran::Service::Representative
        .where("'#{USER_TYPE_VSO}' = ANY(user_types)")
        .pluck(:representative_id)
    end

    # Representative type helper methods

    def process_valid_representative_data(data, processor, entity_type, new_count)
      result = data.map do |record|
        processor.call(record) if record['Registration Num'].present?
        record['Registration Num']
      end
      @ingestion_log&.mark_entity_success!(entity_type, count: new_count)
      result
    end

    def handle_representative_validation_failure(entity_type, rep_type, user_type, new_count)
      @ingestion_log&.mark_entity_failed!(
        entity_type,
        error: 'Count validation failed',
        count: new_count,
        previous_count: get_previous_count(rep_type)
      )
      Veteran::Service::Representative.where('? = ANY(user_types)', user_type).pluck(:representative_id)
    end

    # Combines all representative IDs from attorneys, claim agents, and VSOs
    # @return [Array<String>] Combined array of all representative IDs that should remain in the system
    #   This list is used to identify representatives that are no longer in OGC data and should be removed
    def reload_representatives
      reload_attorneys + reload_claim_agents + reload_vso_reps
    end

    def find_or_create_attorneys(attorney)
      rep = find_or_initialize_by_id(attorney, USER_TYPE_ATTORNEY)
      rep.save
    end

    def find_or_create_claim_agents(claim_agent)
      rep = find_or_initialize_by_id(claim_agent, USER_TYPE_CLAIM_AGENT)
      rep.save
    end

    def find_or_create_vso(vso)
      unless vso['Representative']&.match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/)
        ClaimsApi::Logger.log('VSO', detail: "Rep name not in expected format: #{vso['Registration Num']}")
        return nil
      end

      rep = find_or_initialize_by_id(convert_vso_to_useable_hash(vso), USER_TYPE_VSO)
      rep.save
      rep
    end

    def convert_vso_to_useable_hash(vso)
      last_name, first_name, middle_initial =
        vso['Representative'].match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/).captures

      {
        'Last Name' => last_name&.strip,
        'First Name' => first_name&.strip,
        'Middle Initial' => (middle_initial || '').strip,
        'Registration Num' => vso['Registration Num'],
        'POA Code' => normalize_poa(vso['POA']),
        'Phone' => vso['Rep Phone'] || vso['Org Phone'],
        'City' => vso['Rep City'] || vso['Org City'],
        'State' => vso['Rep State'] || vso['Org State'],
        'Zip' => vso['Rep Zip']
      }
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(
        webhook_url: Settings.edu.slack.webhook_url,
        channel: '#benefits-representation-management-notifications',
        username: 'VSOReloader'
      )
      client.notify(message)
    end

    def fetch_initial_counts
      {
        attorneys: Veteran::Service::Representative.where("'#{USER_TYPE_ATTORNEY}' = ANY(user_types)").count,
        claims_agents: Veteran::Service::Representative.where("'#{USER_TYPE_CLAIM_AGENT}' = ANY(user_types)").count,
        vso_representatives: Veteran::Service::Representative.where("'#{USER_TYPE_VSO}' = ANY(user_types)").count,
        vso_organizations: Veteran::Service::Organization.count
      }
    end

    def ensure_initial_counts
      @initial_counts ||= fetch_initial_counts
      @validation_results ||= {}
    end

    def valid_count?(rep_type, new_count)
      previous_count = get_previous_count(rep_type)

      # If no previous count exists, allow the update
      return true if previous_count.nil? || previous_count.zero?

      # If new count is greater or equal, allow the update
      return true if new_count >= previous_count

      # Calculate decrease percentage
      decrease_percentage = (previous_count - new_count).to_f / previous_count

      if decrease_percentage > DECREASE_THRESHOLD
        # Log to Slack and don't update
        notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, DECREASE_THRESHOLD)
        @validation_results[rep_type] = nil
        false
      else
        @validation_results[rep_type] = new_count
        true
      end
    end

    def get_previous_count(rep_type)
      # Get the most recent count from the database
      latest_total = Veteran::AccreditationTotal.order(created_at: :desc).first

      # If we have a previous count in the database, use it
      # Otherwise, use the current count from the database
      latest_total&.send(rep_type) || @initial_counts[rep_type]
    end

    def notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, threshold)
      message = "⚠️ VSO Reloader Alert: #{rep_type.to_s.humanize} count decreased beyond threshold!\n" \
                "Previous: #{previous_count}\n" \
                "New: #{new_count}\n" \
                "Decrease: #{(decrease_percentage * 100).round(2)}%\n" \
                "Threshold: #{(threshold * 100).round(2)}%\n" \
                'Action: Update skipped, manual review required'

      log_to_slack(message)
      log_message_to_sentry(
        "VSO Reloader threshold exceeded for #{rep_type}",
        :warn,
        previous_count:,
        new_count:,
        decrease_percentage:
      )
    end

    def save_accreditation_totals
      # For manual reprocessing, some types may not be in @validation_results
      # If a type wasn't processed, use the current count from the database
      # If a type was processed and failed validation, it will be nil
      Veteran::AccreditationTotal.create!(
        attorneys: get_count_for_save(:attorneys),
        claims_agents: get_count_for_save(:claims_agents),
        vso_representatives: get_count_for_save(:vso_representatives),
        vso_organizations: get_count_for_save(:vso_organizations)
      )
    end

    def get_count_for_save(rep_type)
      # If the type was processed (exists in validation_results), use that value (even if nil)
      # Otherwise, use the current count from the database
      @validation_results.key?(rep_type) ? @validation_results[rep_type] : @initial_counts[rep_type]
    end

    def calculate_vso_counts(vso_data)
      normalized_poas =
        vso_data
        .map { |v| normalize_poa(v['POA']) }
        .compact_blank
        .uniq

      {
        reps: vso_data.count { |v| v['Representative'].present? && v['Registration Num'].present? },
        orgs: normalized_poas.count
      }
    end

    def process_vso_data(vso_data)
      vso_reps, rep_org_pairs, vso_orgs = extract_vso_entities(vso_data)

      current_poa_codes = vso_orgs.map { |org| org[:poa] }.compact_blank.uniq

      # Always import organizations when processing VSO data to maintain referential integrity
      Veteran::Service::Organization.transaction do
        import_vso_organizations(vso_orgs)
        populate_org_representative_joins!(rep_org_pairs:, poa_codes: current_poa_codes)

        # Retain stale orgs that are no longer in the OGC data, but deactivate their join records
        deactivate_stale_organization_joins(current_poa_codes)
      end

      vso_reps
    end

    def extract_vso_entities(vso_data)
      vso_reps = []
      rep_org_pairs = []

      vso_orgs =
        vso_data.filter_map do |row|
          next unless row['Representative']

          rep_id = row['Registration Num']
          poa = normalize_poa(row['POA'])

          append_seen_rep_id!(vso_reps, rep_id)
          rep = create_vso_rep_if_valid(row)

          rep_org_pairs << [rep_id, poa] if rep.present? && rep.persisted? && rep_id.present? && poa.present?
          build_org_hash(row, poa)
        end.compact.uniq

      [vso_reps, rep_org_pairs, vso_orgs]
    end

    def append_seen_rep_id!(vso_reps, rep_id)
      vso_reps << rep_id if rep_id.present?
    end

    def create_vso_rep_if_valid(row)
      return nil if row['Registration Num'].blank?

      find_or_create_vso(row)
    end

    def build_org_hash(row, poa)
      return nil if poa.blank?

      {
        poa:,
        name: row['Organization Name'],
        phone: row['Org Phone'],
        state: row['Org State']
      }
    end

    def import_vso_organizations(vso_orgs)
      Veteran::Service::Organization.import(vso_orgs, on_duplicate_key_update: %i[name phone state])
    end

    # rubocop:disable Rails/SkipsModelValidations
    def remove_stale_organizations(current_poa_codes)
      return if current_poa_codes.blank?

      stale_poas = Veteran::Service::Organization.where.not(poa: current_poa_codes).pluck(:poa)
      return if stale_poas.empty?

      Veteran::Service::OrganizationRepresentative
        .where(organization_poa: stale_poas, deactivated_at: nil)
        .update_all(deactivated_at: Time.current)
    end
    # rubocop:enable Rails/SkipsModelValidations

    # Syncs representative <-> organization relationships to the latest feed:
    # - Inserts missing joins (seeding acceptance_mode from org.can_accept_digital_poa_requests).
    # - Reactivates joins that re-appear in the feed.
    # - Deactivates joins for orgs in this feed that are missing from the latest run.
    #
    # acceptance_mode is never overwritten by ingestion.
    def populate_org_representative_joins!(rep_org_pairs:, poa_codes:)
      pairs = rep_org_pairs.compact.uniq
      return if pairs.empty? || poa_codes.blank?

      org_accept_map = organization_accept_map(poa_codes)
      rows = build_org_rep_rows(pairs, org_accept_map)
      return if rows.empty?

      insert_missing_org_rep_rows(rows)
      sync_org_rep_active_status!(pairs:, poa_codes:)
    end

    def organization_accept_map(poa_codes)
      Veteran::Service::Organization
        .where(poa: poa_codes)
        .pluck(:poa, :can_accept_digital_poa_requests)
        .to_h
    end

    # NOTE: We intentionally use `insert_all` with a unique constraint on
    # [:organization_poa, :representative_id] so ingestion is idempotent.
    #
    # This behaves like `INSERT ... ON CONFLICT DO NOTHING`:
    # - If a (organization, representative) join row does NOT exist yet,
    #   it is inserted and `acceptance_mode` is seeded from the
    #   organization-wide `can_accept_digital_poa_requests` flag.
    #
    # - If the join row already exists (including cases where
    #   `acceptance_mode` was manually changed later),
    #   the insert conflicts and does nothing.
    #
    # This prevents ingestion from overwriting per-representative
    # `acceptance_mode` once it has been explicitly set.
    #
    # rubocop:disable Rails/SkipsModelValidations
    def insert_missing_org_rep_rows(rows)
      Veteran::Service::OrganizationRepresentative.insert_all(
        rows,
        unique_by: %i[organization_poa representative_id]
      )
    end
    # rubocop:enable Rails/SkipsModelValidations

    # Reactivate joins that re-appear in the feed, and deactivate joins for orgs in this
    # feed that are missing from the latest run.
    def sync_org_rep_active_status!(pairs:, poa_codes:)
      reactivate_org_rep_pairs!(pairs)
      deactivate_missing_org_rep_pairs!(pairs, poa_codes)
    end

    # rubocop:disable Rails/SkipsModelValidations
    def reactivate_org_rep_pairs!(pairs)
      pairs.each_slice(1000) do |slice|
        conditions = slice.map { |_| '(organization_poa = ? AND representative_id = ?)' }.join(' OR ')
        binds = slice.flat_map { |rep_id, poa| [poa, rep_id] }

        Veteran::Service::OrganizationRepresentative
          .where.not(deactivated_at: nil)
          .where(conditions, *binds)
          .update_all(deactivated_at: nil)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations

    # rubocop:disable Rails/SkipsModelValidations
    def deactivate_missing_org_rep_pairs!(pairs, poa_codes)
      expected = pairs.to_set { |rep_id, poa| [poa, rep_id] }
      now = Time.current

      ids_to_deactivate = []

      Veteran::Service::OrganizationRepresentative
        .where(organization_poa: poa_codes, deactivated_at: nil)
        .select(:id, :organization_poa, :representative_id)
        .find_each do |join|
          key = [join.organization_poa, join.representative_id]
          ids_to_deactivate << join.id unless expected.include?(key)
        end

      return if ids_to_deactivate.empty?

      ids_to_deactivate.each_slice(1000) do |slice|
        Veteran::Service::OrganizationRepresentative
          .where(id: slice)
          .update_all(deactivated_at: now)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations

    def build_org_rep_rows(pairs, org_accept_map)
      pairs.filter_map do |rep_id, poa|
        next if rep_id.blank? || poa.blank?

        acceptance_mode = org_accept_map.fetch(poa, false) ? 'any_request' : 'no_acceptance'

        {
          representative_id: rep_id,
          organization_poa: poa,
          acceptance_mode:
        }
      end
    end

    # Maps VSOReloader's rep_type symbols to AccreditationDataIngestionLog entity types
    #
    # @param rep_type [Symbol] The rep_type used in VSOReloader (:attorneys, :claims_agents, etc.)
    # @return [String] The entity type for the log model
    def map_rep_type_to_entity_type(rep_type)
      case rep_type
      when :attorneys then 'attorneys'
      when :claims_agents then 'agents'
      when :vso_representatives then 'representatives'
      when :vso_organizations then 'veteran_service_organizations'
      else rep_type.to_s
      end
    end

    # Completes the ingestion log with overall metrics
    def complete_ingestion_log
      return unless @ingestion_log

      @ingestion_log.complete_ingestion!(
        attorneys: @validation_results[:attorneys] || @initial_counts[:attorneys],
        claims_agents: @validation_results[:claims_agents] || @initial_counts[:claims_agents],
        vso_representatives: @validation_results[:vso_representatives] || @initial_counts[:vso_representatives],
        vso_organizations: @validation_results[:vso_organizations] || @initial_counts[:vso_organizations]
      )
    end

    # Marks the ingestion log as failed
    #
    # @param error_message [String] The error message to log
    def fail_ingestion_log(error_message)
      return unless @ingestion_log

      @ingestion_log.fail_ingestion!(error: error_message)
    end
  end
end
# rubocop:enable Metrics/ClassLength
