# frozen_string_literal: true

require 'kafka/sidekiq/event_bus_submission_job'
require 'kafka/models/form_trace'
require 'kafka/models/test_form_trace'

module Kafka
  VASI_ID = '2103'
  SYSTEM_NAME = 'VA_gov'

  module State
    # Indicates that the event has been received
    RECEIVED = 'received'
    # Indicates that the event has been sent
    SENT = 'sent'
    # Indicates that an error occurred during event processing
    ERROR = 'error'
    # Indicates that the event processing has been completed successfully
    COMPLETED = 'completed'
  end

  # Selects the Kafka topic name.
  #
  # @param use_test_topic [Boolean] Whether to use the test topic. Defaults to false.
  # @return [String] The selected Kafka topic name.
  def self.get_topic(use_test_topic: false)
    if use_test_topic
      Settings.kafka_producer.test_topic_name
    else
      Settings.kafka_producer.topic_name
    end
  end

  # Redacts ICN on any level of nested hash
  #
  # @param hash [Hash] Hash to be searched
  # @return [Hash] Redacted Hash
  def self.redact_icn(hash)
    return hash unless Rails.env.production? || hash.is_a?(Hash)

    stack = [hash]

    while (current = stack.pop)
      current.each do |key, value|
        if key.upcase == 'ICN'
          current[key] = '[REDACTED]'
        elsif value.is_a?(Hash)
          stack.push(value)
        elsif value.is_a?(Array)
          value.each { |item| stack.push(item) if item.is_a?(Hash) }
        end
      end
    end

    hash
  end

  # Submits an test event to the Kafka EventBusSubmissionJob
  #
  # @param payload [Hash] Hash must have only string values
  #
  # @return [void]
  def self.submit_test_event(payload)
    payload = { 'data' => payload }
    form_trace = Kafka::TestFormTrace.new(payload)

    payload = format_trace(form_trace)

    Kafka::EventBusSubmissionJob.perform_async(payload, true)
  end

  # Submits an event to the Kafka EventBusSubmissionJob
  #
  # @param icn [String] The Integration Control Number (ICN) of the user
  # @param current_id [String] The current identifier for the submission, i.e. confirmation number
  # @param submission_name [String] The form ID
  # @param state [String] The state of the event (e.g., received, sent, error, completed)
  # @param next_id [String, nil] (Optional) The next identifier in the process
  #
  # @return [void]
  # rubocop:disable Metrics/ParameterLists
  def self.submit_event(current_id:, submission_name:, state:, icn: nil, prior_id: nil, next_id: nil,
                        additional_ids: nil)
    payload = {
      'icn' => icn,
      'prior_id' => prior_id.to_s,
      'current_id' => current_id.to_s,
      'next_id' => next_id.to_s,
      'submission_name' => submission_name,
      'state' => state,
      'vasi_id' => VASI_ID,
      'system_name' => SYSTEM_NAME,
      'timestamp' => Time.current.iso8601,
      'additional_ids' => additional_ids
    }

    form_trace = Kafka::FormTrace.new(payload)
    payload = format_trace(form_trace)

    Kafka::EventBusSubmissionJob.perform_async(payload, false)
  end
  # rubocop:enable Metrics/ParameterLists

  def self.format_trace(trace)
    raise Common::Exceptions::ValidationErrors, trace.errors unless trace.valid?

    payload = trace.attributes

    payload.deep_transform_keys { |key| key.to_s.camelize(:lower) }
  end
end
