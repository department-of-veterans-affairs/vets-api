# frozen_string_literal: true

require 'sentry_logging'

module RepresentationManagement
  class AccreditationApiEntityCount < ApplicationRecord
    TYPES = RepresentationManagement::GCLAWS::Client::ALLOWED_TYPES
    # The total number of representatives and organizations parsed from the GCLAWS API
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed

    def save_api_counts
      TYPES.each do |type|
        send("#{type}=", current_api_counts[type]) if valid_count?(type, notify: false)
      end

      save!
    rescue => e
      log_error("Error saving API counts: #{e.message}")
    end

    def valid_count?(type, notify: true)
      previous_count = current_db_counts[type]
      new_count = current_api_counts[type]

      # If no previous count exists, allow the update
      return true if previous_count.nil? || previous_count.zero?

      # If new count is greater or equal, allow the update
      return true if new_count >= previous_count

      # Calculate decrease percentage
      decrease_percentage = (previous_count - new_count).to_f / previous_count

      if decrease_percentage > DECREASE_THRESHOLD
        # Log to Slack and don't update
        notify_threshold_exceeded(type, previous_count, new_count, decrease_percentage, DECREASE_THRESHOLD) if notify
        false
      else
        true
      end
    end


    def client
      RepresentationManagement::GCLAWS::Client
    end

    def current_api_counts
      @current_api_counts ||= get_counts_from_api
    end

    def current_db_counts
      @current_db_counts ||= get_counts_from_db
    end

    def get_counts_from_api
      counts = {}
      TYPES.each do |type|
        counts[type] = client.get_accredited_entities(type:, page: 1, page_size: 1).body['totalRecords']
      rescue => e
        log_error("Error fetching count for #{type}: #{e.message}")
      end
      counts
    end

    def get_counts_from_db
      latest_counts = RepresentationManagement::AccreditationApiEntityCount.order(created_at: :desc).first
      {
        agents: latest_counts&.agents || individual_count('claims_agent'),
        attorneys: latest_counts&.attorneys || individual_count('attorney'),
        representatives: latest_counts&.representatives || individual_count('representative'),
        veteran_service_organizations: latest_counts&.veteran_service_organizations || AccreditedOrganization.count
      }
    end

    def individual_count(type)
      AccreditedIndividual.where(individual_type: type).count
    end

    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditationApiEntityCount error: #{message}")
    end

    def log_to_slack_threshold_channel(message)
      slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                             channel: '#benefits-representation-management-notifications',
                                             username: 'RepresentationManagement::AccreditationApiEntityCount')
      slack_client.notify(message)
    end

    def notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, threshold)
      message = "⚠️ AccreditationApiEntityCount Alert: #{rep_type.to_s.humanize} count decreased beyond threshold!\n" \
                "Previous: #{previous_count}\n" \
                "New: #{new_count}\n" \
                "Decrease: #{(decrease_percentage * 100).round(2)}%\n" \
                "Threshold: #{(threshold * 100).round(2)}%\n" \
                'Action: Update skipped, manual review required'

      log_to_slack_threshold_channel(message)
      # TODO Change the following to datadog
      log_error("AccreditationApiEntityCount threshold exceeded for #{rep_type}, previous: #{previous_count}, " \
                "new: #{new_count}, decrease: #{(decrease_percentage * 100).round(2)}%")

    end
  end
end
