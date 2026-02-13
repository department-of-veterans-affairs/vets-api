# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  # Processes address validation and contact updates for AccreditedOrganization records.
  # Accepts a JSON string with an array of organization update data from AccreditationQueueUpdates.
  # Updates name, phone, and raw_address fields, then validates addresses where changed.
  class AccreditedOrganizationsUpdate
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2

    attr_accessor :slack_messages

    def initialize
      @slack_messages = []
      @records_needing_geocoding = []
    end

    # Processes updates for AccreditedOrganization records from XLSX data.
    # @param organizations_json [String] JSON string containing array of org update data.
    #   Each entry: { 'id', 'name', 'phone', 'raw_address', 'address_changed', 'phone_changed', 'name_changed' }
    def perform(organizations_json)
      records_data = JSON.parse(organizations_json)
      records_data.each { |data| process_record(data) }
      enqueue_geocoding_jobs
    rescue => e
      log_error("Error processing job: #{e.message}", send_to_slack: true)
    ensure
      @slack_messages.unshift('RepresentationManagement::AccreditedOrganizationsUpdate') if @slack_messages.any?
      log_to_slack(@slack_messages.join("\n")) unless @slack_messages.empty?
    end

    private

    # Processes an AccreditedOrganization record with contact/address updates from XLSX data.
    # @param data [Hash] Update data with keys: 'id', 'name', 'phone', 'raw_address',
    #   'address_changed', 'phone_changed', 'name_changed'
    def process_record(data)
      record = AccreditedOrganization.find_by(id: data['id'])

      if record.nil?
        log_error("Record not found: #{data['id']}", send_to_slack: false)
        return
      end

      updates = {}
      updates[:name] = data['name'] if data['name_changed']
      updates[:phone] = data['phone'] if data['phone_changed']
      updates[:raw_address] = data['raw_address'] if data['raw_address'].present?

      record.update(updates) if updates.any?

      if data['address_changed'] && !record.validate_address
        log_error("Address validation failed for record #{data['id']}", send_to_slack: false)
        @records_needing_geocoding << record.id
      end
    rescue => e
      log_error("Error processing record #{data['id']}: #{e.message}", send_to_slack: true)
    end

    # Enqueues geocoding jobs for records that failed address validation.
    # Jobs are spaced 2 seconds apart to respect rate limiting.
    # @return [void]
    def enqueue_geocoding_jobs
      return if @records_needing_geocoding.empty?

      @records_needing_geocoding.each_with_index do |record_id, index|
        delay_seconds = index * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(delay_seconds.seconds, 'AccreditedOrganization', record_id)
      end
    rescue => e
      log_error("Error enqueueing geocoding jobs: #{e.message}", send_to_slack: true)
    end

    # Logs an error and optionally adds it to the Slack message array.
    # @param error [String] The error string to be logged.
    def log_error(error, send_to_slack: false)
      message = "RepresentationManagement::AccreditedOrganizationsUpdate: #{error}"
      Rails.logger.error(message)
      @slack_messages << "----- #{message}" if send_to_slack
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'RepresentationManagement::AccreditedOrganizationsUpdate Bot')
      client.notify(message)
    end
  end
end
