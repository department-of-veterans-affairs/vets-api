# frozen_string_literal: true

require 'kafka/sidekiq/event_bus_submission_job'

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
    return hash unless hash.is_a?(Hash)

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
  def self.submit_event(icn:, current_id:, submission_name:, state:, next_id: nil, use_test_topic: false)
    payload = {
      'ICN' => icn,
      'currentId' => current_id.to_s,
      'submissionName' => submission_name,
      'state' => state,
      'vasiId' => VASI_ID,
      'systemName' => SYSTEM_NAME,
      'timestamp' => Time.current.iso8601
    }

    payload.merge!('nextId' => next_id.to_s) if next_id
    payload = { 'data' => payload } if use_test_topic
    Kafka::EventBusSubmissionJob.perform_async(payload, use_test_topic)
  end
  # rubocop:enable Metrics/ParameterLists

  def self.truncate_form_id(form_id)
    dash_index = form_id.index('-')
    return "F#{form_id}" if dash_index.nil?

    "F#{form_id[(dash_index + 1)..]}"
  end
end
