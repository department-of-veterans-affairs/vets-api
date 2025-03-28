# frozen_string_literal: true

require 'kafka/sidekiq/event_bus_submission_job'

# Namespace for Kafka-related classes and modules
module Kafka
  # Defines constants representing various states in the Kafka event processing lifecycle
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

  # Submits an event to the Kafka EventBusSubmissionJob
  #
  # @param icn [String] The Integration Control Number (ICN) of the user
  # @param current_id [String] The current identifier for the submission, i.e. confirmation number
  # @param submission_name [String] The form ID
  # @param state [String] The state of the event (e.g., received, sent, error, completed)
  # @param next_id [String, nil] (Optional) The next identifier in the process
  #
  # @return [void]
  def self.submit_event(icn:, current_id:, submission_name:, state:, next_id: nil)
    Kafka::EventBusSubmissionJob.perform_async(
      'submission_trace_mock_dev',
      {
        'data' => {
          'ICN' => icn,
          'currentID' => current_id,
          'nextID' => next_id,
          'submissionName' => submission_name,
          'state' => state
        }
      }
    )
  end
end
