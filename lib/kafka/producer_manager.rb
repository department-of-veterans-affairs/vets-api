# frozen_string_literal: true

require 'singleton'
require 'waterdrop'
require 'kafka/oauth_token_refresher'

module Kafka
  class ProducerManager
    include Singleton

    attr_reader :producer

    def initialize
      setup_producer if Flipper.enabled?(:kafka_producer)
    end

    private

    def setup_producer
      @producer = WaterDrop::Producer.new do |config|
        config.deliver = true
        config.kafka = {
          'bootstrap.servers': Settings.kafka_producer.broker_urls.join(','),
          'request.required.acks': 1,
          'message.timeout.ms': 100,
          'security.protocol': Settings.kafka_producer.security_protocol,
          'sasl.mechanisms': Settings.kafka_producer.sasl_mechanisms,
        }
        config.logger = Rails.logger
        config.client_class = if Rails.env.test?
                                WaterDrop::Clients::Buffered
                              else
                                WaterDrop::Clients::Rdkafka
                              end

        # Authentication to MSK via IAM OauthBearer token
        # Once we're ready to test connection to the Event Bus, this should be uncommented
        config.oauth.token_provider_listener = Kafka::OauthTokenRefresher.new unless Rails.env.test?
      end
      setup_instrumentation
    end

    def setup_instrumentation
      producer.monitor.subscribe('error.occurred') do |event|
        producer_id = event[:producer_id]
        case event[:type]
        when 'librdkafka.dispatch_error'
          Rails.logger.error(
            "Waterdrop [#{producer_id}]: Message with label: #{event[:delivery_report].label} failed to be delivered"
          )
        else
          Rails.logger.error "Waterdrop [#{producer_id}]: #{event[:type]} occurred"
        end
      end

      producer.monitor.subscribe('message.acknowledged') do |event|
        producer_id = event[:producer_id]
        offset = event[:offset]

        Rails.logger.info "WaterDrop [#{producer_id}] delivered message with offset: #{offset}"
      end
    end
  end
end
