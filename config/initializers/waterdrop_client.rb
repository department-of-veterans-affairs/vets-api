require 'aws_msk_iam_sasl_signer'
require 'flipper'
require 'waterdrop'

Rails.application.config.after_initialize do
  if Flipper.enabled?(:kafka_producer)

    class OAuthTokenRefresher
      # Refresh OAuth tokens when required by the WaterDrop connection lifecycle
      def on_oauthbearer_token_refresh(event)
        signer = AwsMskIamSaslSigner::MSKTokenProvider.new(region: Settings.kafka_producer.region)
        # This might need to be based on an AWS profile instead of a role ARN
        #   token = signer.generate_auth_token_from_profile(
        #    aws_profile: 'my-profile'
        # )
        token = signer.generate_auth_token_from_role_arn(
          role_arn: Settings.kafka_producer.role_arn
        )

        if token
          event[:bearer].oauthbearer_set_token(
            token: token.token,
            lifetime_ms: token.expiration_time_ms,
            principal_name: 'kafka-cluster'
          )
        else
          event[:bearer].oauthbearer_set_token_failure(
            token.failure_reason
          )
        end
      end
    end

    KAFKA_PRODUCER = WaterDrop::Producer.new do |config|
      config.deliver = true
      config.kafka = {
        'bootstrap.servers': Settings.kafka_producer.broker_urls.join(','),
        'request.required.acks': 1,
        'message.timeout.ms': 100
      }
      config.logger = Rails.logger
      # Use dummy only for tests
      config.client_class = if Rails.env.test?
                              WaterDrop::Clients::Buffered
                            else
                              WaterDrop::Clients::Rdkafka
                            end
      # Authentication to MSK via IAM OauthBearer token
      # Once we're ready to test connection to the Event Bus, this should be uncommented
      # config.oauth.token_provider_listener = OAuthTokenRefresher.new
    end

    KAFKA_PRODUCER.monitor.subscribe(
      WaterDrop::Instrumentation::LoggerListener.new(
        Rails.logger,
        log_messages: true
      )
    )

    KAFKA_PRODUCER.monitor.subscribe('error.occurred') do |event|
      producer_id = event[:producer_id]
      case event[:type]
      when 'librdkafka.dispatch_error'
        Rails.logger.error "Waterdrop [#{producer_id}]: Message with label: #{event[:delivery_report].label} failed to be delivered"
      else
        Rails.logger.error "Waterdrop [#{producer_id}]: #{event[:type]} occurred"
      end
    end

    KAFKA_PRODUCER.monitor.subscribe('message.acknowledged') do |event|
      producer_id = event[:producer_id]
      offset = event[:offset]

      Rails.logger.info "WaterDrop [#{producer_id}] delivered message with offset: #{offset}"
    end
  end
end
