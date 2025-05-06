# frozen_string_literal: true

require 'aws_msk_iam_sasl_signer'

module Kafka
  class OauthTokenRefresher
    # Refresh OAuth tokens when required by the WaterDrop connection lifecycle
    def on_oauthbearer_token_refresh(event)
      signer = AwsMskIamSaslSigner::MSKTokenProvider.new(region: Settings.kafka_producer.aws_region)
      token = signer.generate_auth_token_from_role_arn(
        Settings.kafka_producer.aws_role_arn
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
end
