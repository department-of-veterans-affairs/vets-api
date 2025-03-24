# frozen_string_literal: true

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
end
