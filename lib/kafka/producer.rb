module Kafka
  module Producer
    def self.producer
      @producer = KAFKA_PRODUCER
    end

    # Here we will eventually serialize the payload against an Avro schema
    def self.produce(topic, payload)
      producer.produce_sync(topic: topic, payload: payload.to_json)
    rescue => e
      # https://karafka.io/docs/WaterDrop-Error-Handling/
      # Errors are rescued and re-raised to demonstrate the types of errors that can occur
      case e
      when WaterDrop::Errors::MessageInvalidError
        # This error is raised when the message is invalid and before attempting to send it to Kafka
        Rails.logger.error "Message is invalid: #{e}"
        raise e
      when WaterDrop::Errors::ProduceError
        # This error likely means that the message was not delivered to Kafka.
        Rails.logger.error 'Producer error. See the logs for more information. This dispatch will not reach Kafka'
        raise e
      else
        # Any other errors. This should not happen and indicates trouble.
        Rails.logger.error "An unexpected error occurred while producing a message to #{topic}. Please check the logs for more information. This dispatch will not reach Kafka"
        raise e
      end
    end
  end
end
