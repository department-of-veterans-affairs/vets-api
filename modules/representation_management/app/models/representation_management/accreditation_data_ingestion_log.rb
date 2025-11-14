# frozen_string_literal: true

module RepresentationManagement
  # Tracks the progress and status of accreditation data ingestion processes
  #
  # This class monitors data ingestion from various sources (Accreditation API or Trexler file)
  # and tracks the status of each entity type (agents, attorneys, representatives, VSOs)
  # throughout the ingestion process.
  #
  # @example Starting a new ingestion run
  #   log = AccreditationDataIngestionLog.start_ingestion!(
  #     dataset: :accreditation_api
  #   )
  #
  # @example Updating entity status
  #   log.mark_entity_running!(:agents)
  #   log.mark_entity_success!(:agents, count: 1500)
  #
  # @example Completing the ingestion
  #   log.complete_ingestion!
  class AccreditationDataIngestionLog < ApplicationRecord
    self.table_name = 'accreditation_data_ingestion_logs'

    # Dataset sources for accreditation data
    enum :dataset, { accreditation_api: 0, trexler_file: 1 }

    # Overall ingestion process status
    enum :status, { running: 0, success: 1, failed: 2 }

    # Entity status enums (agents, attorneys, representatives, VSOs)
    ENTITY_STATUS_VALUES = { not_started: 0, running: 1, success: 2, failed: 3 }.freeze

    enum :agents_status, ENTITY_STATUS_VALUES, prefix: :agents
    enum :attorneys_status, ENTITY_STATUS_VALUES, prefix: :attorneys
    enum :representatives_status, ENTITY_STATUS_VALUES, prefix: :representatives
    enum :veteran_service_organizations_status, ENTITY_STATUS_VALUES, prefix: :veteran_service_organizations

    # Valid entity types that can be tracked
    ENTITY_TYPES = %w[agents attorneys representatives veteran_service_organizations].freeze

    # Starts a new ingestion run and returns the created log
    #
    # @param dataset [Symbol] The data source (:accreditation_api or :trexler_file)
    # @return [AccreditationDataIngestionLog] The created log record
    # @example
    #   log = AccreditationDataIngestionLog.start_ingestion!(dataset: :accreditation_api)
    def self.start_ingestion!(dataset:)
      create!(dataset:, status: :running, started_at: Time.current)
    end

    # Finds the most recent successfully completed log
    #
    # @return [AccreditationDataIngestionLog, nil] The most recent successful log or nil
    def self.most_recent_successful
      where(status: :success).order(finished_at: :desc).first
    end

    # Finds the most recent successfully completed log for a specific dataset
    #
    # @param dataset [Symbol] The dataset to filter by (:accreditation_api or :trexler_file)
    # @return [AccreditationDataIngestionLog, nil] The most recent successful log for that dataset
    def self.most_recent_successful_for_dataset(dataset)
      where(status: :success, dataset:).order(finished_at: :desc).first
    end

    # Finds the currently running log for a specific dataset
    #
    # @param dataset [Symbol] The dataset to filter by (:accreditation_api or :trexler_file)
    # @return [AccreditationDataIngestionLog, nil] The currently running log or nil
    def self.current_running_for_dataset(dataset)
      where(status: :running, dataset:).order(started_at: :desc).first
    end

    # Marks a specific entity type as running
    #
    # @param entity_type [String, Symbol] The entity type
    #   (agents, attorneys, representatives, veteran_service_organizations)
    # @return [Boolean] true if saved successfully
    # @example
    #   log.mark_entity_running!(:agents)
    def mark_entity_running!(entity_type)
      validate_entity_type!(entity_type)
      send("#{entity_type}_running!")
      save!
    end

    # Marks a specific entity type as successfully completed and optionally stores metrics
    #
    # @param entity_type [String, Symbol] The entity type
    # @param metrics_data [Hash] Optional metrics to merge into the metrics column
    # @return [Boolean] true if saved successfully
    # @example
    #   log.mark_entity_success!(:agents, count: 1500, duration: 45.2)
    def mark_entity_success!(entity_type, **metrics_data)
      validate_entity_type!(entity_type)
      send("#{entity_type}_success!")
      merge_entity_metrics!(entity_type, metrics_data) if metrics_data.any?
      save!
    end

    # Marks a specific entity type as failed and optionally stores error information
    #
    # @param entity_type [String, Symbol] The entity type
    # @param metrics_data [Hash] Optional metrics including error information
    # @return [Boolean] true if saved successfully
    # @example
    #   log.mark_entity_failed!(:agents, error: "Connection timeout")
    def mark_entity_failed!(entity_type, **metrics_data)
      validate_entity_type!(entity_type)
      send("#{entity_type}_failed!")
      merge_entity_metrics!(entity_type, metrics_data) if metrics_data.any?
      save!
    end

    # Completes the ingestion run with success status
    #
    # @param metrics_data [Hash] Optional overall metrics to store
    # @return [Boolean] true if saved successfully
    # @example
    #   log.complete_ingestion!(total_duration: 120.5, total_records: 5000)
    def complete_ingestion!(**metrics_data)
      self.status = :success
      self.finished_at = Time.current
      merge_metrics!(metrics_data) if metrics_data.any?
      save!
    end

    # Marks the ingestion run as failed
    #
    # @param metrics_data [Hash] Optional metrics including error information
    # @return [Boolean] true if saved successfully
    # @example
    #   log.fail_ingestion!(error: "API connection failed", partial_results: true)
    def fail_ingestion!(**metrics_data)
      self.status = :failed
      self.finished_at = Time.current
      merge_metrics!(metrics_data) if metrics_data.any?
      save!
    end

    # Returns the duration of the ingestion run if completed
    #
    # @return [Float, nil] Duration in seconds or nil if not finished
    def duration
      finished_at ? finished_at - started_at : nil
    end

    # Checks if all entity types have completed (either success or failed)
    #
    # @return [Boolean] true if all entities are done processing
    def all_entities_completed?
      ENTITY_TYPES.all? { |entity_type| %w[success failed].include?(send("#{entity_type}_status")) }
    end

    # Checks if any entity type has failed
    #
    # @return [Boolean] true if any entity failed
    def any_entity_failed?
      ENTITY_TYPES.any? { |entity_type| send("#{entity_type}_failed?") }
    end

    # Returns a hash of all entity statuses
    #
    # @return [Hash] Hash mapping entity types to their status strings
    # @example
    #   log.entity_statuses
    #   # => { "agents" => "success", "attorneys" => "running", ... }
    def entity_statuses
      ENTITY_TYPES.index_with { |entity_type| send("#{entity_type}_status") }
    end

    private

    # Validates that the entity type is valid
    #
    # @param entity_type [String, Symbol] The entity type to validate
    # @raise [ArgumentError] if the entity type is not valid
    def validate_entity_type!(entity_type)
      return if ENTITY_TYPES.include?(entity_type.to_s)

      raise ArgumentError, "Invalid entity type: #{entity_type}. Must be one of: #{ENTITY_TYPES.join(', ')}"
    end

    # Merges metrics data into the metrics JSONB column under an entity-specific key
    #
    # @param entity_type [String, Symbol] The entity type
    # @param data [Hash] The metrics data to merge
    def merge_entity_metrics!(entity_type, data)
      self.metrics ||= {}
      self.metrics[entity_type.to_s] ||= {}
      self.metrics[entity_type.to_s].merge!(data.deep_stringify_keys)
    end

    # Merges metrics data into the metrics JSONB column at the top level
    #
    # @param data [Hash] The metrics data to merge
    def merge_metrics!(data)
      self.metrics ||= {}
      self.metrics.merge!(data.deep_stringify_keys)
    end
  end
end
