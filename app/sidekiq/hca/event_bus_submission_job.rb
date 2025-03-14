# frozen_string_literal: true

require 'kafka/avro_producer'
module HCA
  class EventBusSubmissionJob
    include Sidekiq::Job
    sidekiq_options retry: false

    def perform(topic, payload)
      Kafka::AvroProducer.new.produce(topic, payload)
    end
  end
end
