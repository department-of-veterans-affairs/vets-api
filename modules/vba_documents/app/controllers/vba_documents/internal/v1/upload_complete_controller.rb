# frozen_string_literal: true

require 'common/exceptions'

module VBADocuments
  module Internal
    module V1
      class UploadCompleteController < ApplicationController
        skip_before_action(:authenticate)
        before_action :verify_message
        before_action :verify_topic_arn

        def create
          case request.headers['x-amz-sns-message-type']
          when 'Notification'
            json_message['Records'].each do |record|
              upload_id = record['s3']['object']['key']
              process_upload(upload_id)
            end
          when 'SubscriptionConfirmation'
            client = Aws::SNS::Client.new(region: Settings.vba_documents.sns.region)
            client.confirm_subscription(
              authenticate_on_unsubscribe: 'authenticateOnUnsubscribe',
              token: json_params['Token'],
              topic_arn: json_params['TopicArn']
            )
          else
            raise Common::Exceptions::ParameterMissing, 'x-amz-sns-message-type'
          end

          head :no_content
        end

        private

        # Make sure the message we're receiving is from the topic
        # we're expecting to get messages from
        def verify_topic_arn
          unless Settings.vba_documents.sns.topic_arns.include? json_params['TopicArn']
            raise Common::Exceptions::ParameterMissing, 'TopicArn'
          end
        end

        def verify_message
          verifier = Aws::SNS::MessageVerifier.new
          unless verifier.authentic?(read_body)
            raise Common::Exceptions::MessageAuthenticityError.new(
              raw_post: read_body,
              signature: json_params['Signature']
            )
          end
        end

        def json_params
          @json_body ||= JSON.parse(read_body)
        end

        def json_message
          @json_message ||= JSON.parse(json_params['Message'])
        end

        def read_body
          @body ||= request.body.read
        end

        def process_upload(upload_id)
          upload = VBADocuments::UploadSubmission.find_by(guid: upload_id)
          store = VBADocuments::ObjectStore.new
          raise Common::Exceptions::RecordNotFound, upload_id unless upload && store.bucket.object(upload.guid).exists?

          if upload.status.eql?('pending')
            Rails.logger.info("VBADocuments: Processing: #{upload.inspect}")
            upload.update(status: 'uploaded')
            VBADocuments::UploadProcessor.perform_async(upload_id, caller: self.class.name)
          else
            Rails.logger.info("VBADocuments: upload_complete_controller late/duplicate notification: #{upload.inspect}")
          end
        end
      end
    end
  end
end
