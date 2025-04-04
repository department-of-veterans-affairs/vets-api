# frozen_string_literal: true

require 'active_support/concern'

module Kafka
  module Topic
    extend ActiveSupport::Concern

    # Selects the Kafka topic name.
    #
    # @param use_test_topic [Boolean] Whether to use the test topic. Defaults to false.
    # @return [String] The selected Kafka topic name.
    def get_topic(use_test_topic: false)
      if use_test_topic
        Settings.kafka_producer.test_topic_name
      else
        Settings.kafka_producer.topic_name
      end
    end
  end
end
