# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Veteran
  class VSOReloader < BaseReloader
    include Sidekiq::Job
    include SentryLogging

    # The total number of representatives and organizations parsed from the ingested .ASP files
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed

    # User type constants
    USER_TYPE_ATTORNEY = 'attorney'
    USER_TYPE_CLAIM_AGENT = 'claim_agents'
    USER_TYPE_VSO = 'veteran_service_officer'

    def perform
      # Track initial counts before processing
      @initial_counts = fetch_initial_counts
      @validation_results = {}

      # Collect all valid representative IDs from OGC data
      # This array is used to determine which representatives should be kept vs removed
      array_of_organizations = reload_representatives

      # Save the results to the database
      save_accreditation_totals

      # Remove representatives that are no longer in the OGC data
      # By using where.not, we delete anyone whose ID is NOT in the array returned by reload_representatives
      Veteran::Service::Representative.where.not(representative_id: array_of_organizations).find_each do |rep|
        # These are test users that Sandbox requires.  Don't delete them.
        next if rep.first_name == 'Tamara' && rep.last_name == 'Ellis'
        next if rep.first_name == 'John' && rep.last_name == 'Doe'

        rep.destroy!
      end
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("OGC connection failed: #{e.message}", :warn)
      log_to_slack('VSO Reloader failed to connect to OGC')
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("VSO Reloading error: #{e.message}", :warn)
      log_to_slack('VSO Reloader job has failed!')
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
      ensure_initial_counts
      vso_data = fetch_data('orgsexcellist.asp')
      counts = calculate_vso_counts(vso_data)

      # Validate both counts - if either fails, skip processing both to maintain data integrity
      reps_valid = valid_count?(:vso_representatives, counts[:reps])
      orgs_valid = valid_count?(:vso_organizations, counts[:orgs])
      process_vsos = reps_valid && orgs_valid

      if process_vsos
        process_vso_data(vso_data)
      else
        # Return existing VSO rep IDs to prevent deletion
        Veteran::Service::Representative
          .where("'#{USER_TYPE_VSO}' = ANY(user_types)")
          .pluck(:representative_id)
      end
    end

    # Common method for reloading attorney and claim agent data
    # @param endpoint [String] OGC endpoint to fetch data from
    # @param rep_type [Symbol] Type of representative for validation (:attorneys, :claims_agents)
    # @param user_type [String] Database user type constant
    # @param processor [Method] Method to process each record
    # @return [Array<String>] Representative IDs - either newly processed IDs or existing IDs if validation fails
    def reload_representative_type(endpoint:, rep_type:, user_type:, processor:)
      ensure_initial_counts
      data = fetch_data(endpoint)
      new_count = data.count { |record| record['Registration Num'].present? }

      if valid_count?(rep_type, new_count)
        data.map do |record|
          processor.call(record) if record['Registration Num'].present?
          record['Registration Num']
        end
      else
        # Return existing IDs to prevent deletion
        Veteran::Service::Representative.where("'#{user_type}' = ANY(user_types)").pluck(:representative_id)
      end
    end

    private

    # Combines all representative IDs from attorneys, claim agents, and VSOs
    # @return [Array<String>] Combined array of all representative IDs that should remain in the system
    #   This list is used to identify representatives that are no longer in OGC data and should be removed
    def reload_representatives
      reload_attorneys + reload_claim_agents + reload_vso_reps
    end

    def find_or_create_attorneys(attorney)
      rep = find_or_initialize(attorney)
      rep.user_types << USER_TYPE_ATTORNEY unless rep.user_types.include?(USER_TYPE_ATTORNEY)
      rep.save
    end

    def find_or_create_claim_agents(claim_agent)
      rep = find_or_initialize(claim_agent)
      rep.user_types << USER_TYPE_CLAIM_AGENT unless rep.user_types.include?(USER_TYPE_CLAIM_AGENT)
      rep.save
    end

    def find_or_create_vso(vso)
      unless vso['Representative'].match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/)
        ClaimsApi::Logger.log('VSO',
                              detail: "Rep name not in expected format: #{vso['Registration Num']}")
        return
      end

      last_name, first_name, middle_initial = vso['Representative']
                                              .match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/).captures

      last_name = last_name.strip

      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: vso['Registration Num'],
                                                                   first_name:,
                                                                   last_name:)
      poa_code = vso['POA'].gsub(/\W/, '')
      rep.poa_codes << poa_code unless rep.poa_codes.include?(poa_code)

      rep.phone = vso['Org Phone']
      rep.user_types << USER_TYPE_VSO unless rep.user_types.include?(USER_TYPE_VSO)
      rep.middle_initial = middle_initial.presence || ''
      rep.save
    end

    def log_to_slack(message)
      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#api-benefits-claims',
                                       username: 'VSOReloader')
      client.notify(message)
    end

    def log_to_slack_threshold_channel(message)
      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'VSOReloader')
      client.notify(message)
    end

    def fetch_initial_counts
      {
        attorneys: Veteran::Service::Representative.where("'#{USER_TYPE_ATTORNEY}' = ANY(user_types)").count,
        claims_agents: Veteran::Service::Representative.where("'#{USER_TYPE_CLAIM_AGENT}' = ANY(user_types)").count,
        vso_representatives: Veteran::Service::Representative
          .where("'#{USER_TYPE_VSO}' = ANY(user_types)").count,
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

      log_to_slack_threshold_channel(message)
      log_message_to_sentry("VSO Reloader threshold exceeded for #{rep_type}", :warn,
                            previous_count:,
                            new_count:,
                            decrease_percentage:)
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
      {
        reps: vso_data.count { |v| v['Representative'].present? && v['Registration Num'].present? },
        orgs: vso_data.map { |v| v['POA'] }.compact.uniq.count # rubocop:disable Rails/Pluck
      }
    end

    def process_vso_data(vso_data)
      vso_reps = []
      vso_orgs = vso_data.map do |vso_rep|
        next unless vso_rep['Representative']

        find_or_create_vso(vso_rep) if vso_rep['Registration Num'].present?
        vso_reps << vso_rep['Registration Num']
        {
          poa: vso_rep['POA'].gsub(/\W/, ''),
          name: vso_rep['Organization Name'],
          phone: vso_rep['Org Phone'],
          state: vso_rep['Org State']
        }
      end.compact.uniq

      # Always import organizations when processing VSO data to maintain referential integrity
      Veteran::Service::Organization.import(vso_orgs, on_duplicate_key_update: %i[name phone state])

      vso_reps
    end
  end
end
