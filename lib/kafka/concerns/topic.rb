# frozen_string_literal: true

module Kafka
  module Topic
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

    # Redacts ICN on any level of nested hash
    #
    # @param hash [Hash] Hash to be searched
    # @return [Hash] Redacted Hash
    def redact_icn(hash)
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
  end
end
