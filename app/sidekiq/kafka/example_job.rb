require 'kafka/avro_producer'
module Kafka
  class ExampleJob
    include Sidekiq::Job
    # Errors that might occur during the job execution are usually not retryable, though we might want to experiment with this in practice
    sidekiq_options retry: false

    def perform(topic, payload)
      Kafka::AvroProducer.new.produce(topic, payload)
    end
  end
end
