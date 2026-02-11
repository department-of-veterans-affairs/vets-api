# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  # This is the second job in a two job process for updating accredited entities.
  # Processes address validation for AccreditedIndividual records by ID.
  # This class finds AccreditedIndividual records and calls their validate_address method.
  # Works for all individual types: agents, attorneys, and representatives.
  # Note: This job only processes individuals. VSOs (AccreditedOrganization records) do not require
  # address validation as the API does not provide address data for organizations.
  class AccreditedIndividualsUpdate
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2

    attr_accessor :slack_messages

    def initialize
      @slack_messages = []
      @records_needing_geocoding = []
    end

    # Processes address validation for AccreditedIndividuals by ID.
    # This method finds records by ID and calls validate_address on each one.
    # For records where address validation fails, enqueues geocoding jobs.
    # Works for all individual types: agents, attorneys, and representatives.
    # @param record_ids [Array<Integer>] Array of AccreditedIndividual IDs to validate.
    def perform(record_ids)
      record_ids.each { |record_id| process_record(record_id) }
      enqueue_geocoding_jobs
    rescue => e
      log_error("Error processing job: #{e.message}", send_to_slack: true)
    ensure
      @slack_messages.unshift('RepresentationManagement::AccreditedIndividualsUpdate') if @slack_messages.any?
      log_to_slack(@slack_messages.join("\n")) unless @slack_messages.empty?
    end

    private

    # Processes individual AccreditedIndividual record by ID.
    # Finds the record and calls validate_address on it.
    # If validation fails, adds the record to the geocoding queue.
    # If the record is not found or validation fails, the error is logged.
    # @param record_id [Integer] The AccreditedIndividual ID.
    def process_record(record_id)
      record = AccreditedIndividual.find_by(id: record_id)

      if record.nil?
        log_error("Record not found: #{record_id}", send_to_slack: false)
        return
      end

      unless record.validate_address
        log_error("Address validation failed for record #{record_id}", send_to_slack: false)
        @records_needing_geocoding << record.id
      end
    rescue => e
      log_error("Error processing record #{record_id}: #{e.message}", send_to_slack: true)
    end

    # Enqueues geocoding jobs for records that failed address validation.
    # Jobs are spaced 2 seconds apart to respect rate limiting.
    # @return [void]
    def enqueue_geocoding_jobs
      return if @records_needing_geocoding.empty?

      @records_needing_geocoding.each_with_index do |record_id, index|
        delay_seconds = index * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(delay_seconds.seconds, 'AccreditedIndividual', record_id)
      end
    rescue => e
      log_error("Error enqueueing geocoding jobs: #{e.message}", send_to_slack: true)
    end

    # Logs an error and optionally adds it to the Slack message array.
    # @param error [String] The error string to be logged.
    def log_error(error, send_to_slack: false)
      message = "RepresentationManagement::AccreditedIndividualsUpdate: #{error}"
      Rails.logger.error(message)
      @slack_messages << "----- #{message}" if send_to_slack
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'RepresentationManagement::AccreditedIndividualsUpdate Bot')
      client.notify(message)
    end
  end
end
