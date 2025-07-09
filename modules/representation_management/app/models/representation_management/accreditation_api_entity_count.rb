# frozen_string_literal: true

module RepresentationManagement
  # Tracks and validates counts of accredited entities from the GCLAWS API
  #
  # This class stores historical count data for different types of accredited
  # entities (agents, attorneys, representatives, veteran service organizations)
  # and enforces validation rules to prevent dramatic decreases in counts which
  # might indicate data integrity issues.
  #
  # @example Saving new API counts
  #   counter = AccreditationApiEntityCount.new
  #   counter.save_api_counts
  #
  # @example Checking if a count is valid
  #   counter = AccreditationApiEntityCount.new
  #   counter.valid_count?('agents')
  class AccreditationApiEntityCount < ApplicationRecord
    self.table_name = 'accreditation_api_entity_counts'

    # Entity types supported by the GCLAWS API
    TYPES = RepresentationManagement::GCLAWS::Client::ALLOWED_TYPES.map(&:to_sym).freeze
    ENTITY_CONFIG = RepresentationManagement::ENTITY_CONFIG

    # The total number of representatives and organizations parsed from the GCLAWS API
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed

    # Retrieves current counts from the API and saves them to the database
    # if they pass validation checks.
    #
    # @return [Boolean] true if save was successful, false otherwise
    def save_api_counts
      TYPES.each do |type|
        if valid_count?(type)
          send("#{type}=", current_api_counts[type])
        else
          previous_count = current_db_counts[type]
          new_count = current_api_counts[type]
          decrease_percentage = (previous_count - new_count).to_f / previous_count
          notify_threshold_exceeded(type, previous_count, new_count, decrease_percentage, DECREASE_THRESHOLD)
        end
      end

      save!
    rescue => e
      log_error("Error saving API counts: #{e.message}")
    end

    # Validates that a new count doesn't decrease too dramatically from the previous count according to the
    # DECREASE_THRESHOLD.
    #
    # @param type [Symbol] The entity type to validate (:agents, :attorneys, etc.)
    # @return [Boolean] true if count is valid, false otherwise
    def valid_count?(type)
      previous_count = current_db_counts[type]
      new_count = current_api_counts[type]

      # If no previous count exists, allow the update
      return true if previous_count.nil? || previous_count.zero?

      # If new count is greater or equal, allow the update
      return true if new_count >= previous_count

      # Calculate decrease percentage
      decrease_percentage = (previous_count - new_count).to_f / previous_count
      decrease_percentage <= DECREASE_THRESHOLD
    end

    private

    # @return [RepresentationManagement::GCLAWS::Client] The client for GCLAWS API calls
    def client
      RepresentationManagement::GCLAWS::Client
    end

    # @return [Hash] The current counts from the API for all entity types
    def current_api_counts
      @current_api_counts ||= get_counts_from_api
    end

    # Fetches entity counts from the GCLAWS API
    #
    # @return [Hash] A hash mapping entity types to their counts
    def get_counts_from_api
      counts = {}
      TYPES.each do |type|
        # We're fetching with a page size of 1 to get the fastest possible response for the total count
        counts[type] = client.get_accredited_entities(type:, page: 1, page_size: 1).body['totalRecords']
      rescue => e
        log_error("Error fetching count for #{type}: #{e.message}")
      end
      counts
    end

    # @return [Hash] The most recent counts from the database for all entity types
    def current_db_counts
      @current_db_counts ||= get_counts_from_db
    end

    # Gets the most recent counts from the database, starting with records of this model and falling back to counting
    # records in the database if no previous counts exist
    #
    # @return [Hash] A hash mapping entity types to their counts
    def get_counts_from_db
      latest_counts = RepresentationManagement::AccreditationApiEntityCount.order(created_at: :desc).first
      # All of the counts fallback to counting records in the database if the latest counts are not available.
      {
        agents: latest_counts&.agents || fallback_individual_count(RepresentationManagement::AGENTS),
        attorneys: latest_counts&.attorneys || fallback_individual_count(RepresentationManagement::ATTORNEYS),
        representatives: latest_counts&.representatives || fallback_individual_count(RepresentationManagement::REPRESENTATIVES),
        veteran_service_organizations: latest_counts&.veteran_service_organizations ||
          AccreditedOrganization.count
      }
    end

    def fallback_individual_count(entity_type)
      individual_count(ENTITY_CONFIG.send(entity_type).individual_type)
    end

    # Counts the number of accredited individuals of a specific type
    #
    # @param type [String] The individual type ('claims_agent', 'attorney', etc.)
    # @return [Integer] The count of individuals of the specified type
    def individual_count(type)
      AccreditedIndividual.where(individual_type: type).count
    end

    # Notification and logging methods
    # Notifies stakeholders when an entity count decreases beyond the threshold
    #
    # @param rep_type [Symbol] The entity type that exceeded the threshold
    # @param previous_count [Integer] The previous count
    # @param new_count [Integer] The new count
    # @param decrease_percentage [Float] The calculated decrease percentage
    # @param threshold [Float] The threshold that was exceeded
    def notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, threshold)
      message = "⚠️ AccreditationApiEntityCount Alert: #{rep_type.to_s.humanize} count decreased beyond threshold!\n" \
                "Previous: #{previous_count}\n" \
                "New: #{new_count}\n" \
                "Decrease: #{(decrease_percentage * 100).round(2)}%\n" \
                "Threshold: #{(threshold * 100).round(2)}%\n" \
                'Action: Update skipped, manual review required'

      log_to_slack_threshold_channel(message)
      log_error("AccreditationApiEntityCount threshold exceeded for #{rep_type}, previous: #{previous_count}, " \
                "new: #{new_count}, decrease: #{(decrease_percentage * 100).round(2)}%")
    end

    # Sends a notification to the Slack channel
    #
    # @param message [String] The message to send to Slack
    def log_to_slack_threshold_channel(message)
      slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                             channel: '#benefits-representation-management-notifications',
                                             username: 'RepresentationManagement::AccreditationApiEntityCount')
      slack_client.notify(message)
    end

    # Logs an error message to the Rails logger
    #
    # @param message [String] The error message to log
    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditationApiEntityCount error: #{message}")
    end
  end
end
