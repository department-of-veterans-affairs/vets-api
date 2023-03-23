# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Document SNS upload complete notification', type: :request do
  context 'with a subscriptionconfirmation message type' do
    # rubocop:disable Layout/LineLength
    let(:headers) do
      {
        'x-amz-sns-message-type' => 'SubscriptionConfirmation',
        'x-amz-sns-message-id' => '165545c9-2a5c-472c-8df2-7ff2be2b3b1b',
        'x-amz-sns-topic-arn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Content-Length' => '1336',
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Host' => 'www.example.com',
        'Connection' => 'Keep-Alive',
        'User-Agent' => 'Amazon Simple Notification Service Agent'
      }
    end

    let(:token) do
      '2336412f37fb687f5d51e6e241d09c805a5a57b30d712f794cc5f6a988666d92768dd60a747ba6f3beb71854e285d6ad02428b09ceece29417f1f02d609c582afbacc99c583a916b9981dd2728f4ae6fdb82efd087cc3b7849e05798d2d2785c03b0879594eeac82c01f235d0e717736'
    end

    let(:body) do
      {
        'Type' => 'SubscriptionConfirmation',
        'MessageId' => '165545c9-2a5c-472c-8df2-7ff2be2b3b1b',
        'Token' => token,
        'TopicArn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Message' => 'You have chosen to subscribe to the topic arn:aws:sns:us-west-2:123456789012:MyTopic.\nTo confirm the subscription, visit the SubscribeURL included in this message.',
        'SubscribeURL' => 'https://sns.us-west-2.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn:aws:sns:us-west-2:123456789012:MyTopic&Token=2336412f37fb687f5d51e6e241d09c805a5a57b30d712f794cc5f6a988666d92768dd60a747ba6f3beb71854e285d6ad02428b09ceece29417f1f02d609c582afbacc99c583a916b9981dd2728f4ae6fdb82efd087cc3b7849e05798d2d2785c03b0879594eeac82c01f235d0e717736',
        'Timestamp' => '2012-04-26T20:45:04.751Z',
        'SignatureVersion' => '1',
        'Signature' => 'EXAMPLEpH+DcEwjAPg8O9mY8dReBSwksfg2S7WKQcikcNKWLQjwu6A4VbeS0QHVCkhRS7fUQvi2egU3N858fiTDN6bkkOxYDVrY0Ad8L10Hs3zH81mtnPk5uvvolIC1CXGu43obcgFxeL3khZl8IKvO61GWB6jI9b5+gLPoBc1Q=',
        'SigningCertURL' => 'https://sns.us-west-2.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem'
      }.to_json
    end

    # rubocop:enable Layout/LineLength
    context 'verified message' do
      it 'confirms the subscription' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic'],
                      'region' => 'us-gov-west-1') do
          client = double(Aws::SNS::Client)
          expect(client).to receive(:confirm_subscription).with(
            authenticate_on_unsubscribe: 'authenticateOnUnsubscribe',
            token:,
            topic_arn: 'arn:aws:sns:us-west-2:123456789012:MyTopic'
          )
          expect(Aws::SNS::Client).to receive(:new).with(region: 'us-gov-west-1').and_return(client)
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(true)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context 'non-verified-message' do
      it 'responds with a message verification error' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic'],
                      'region' => 'us-gov-west-1') do
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(false)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'with incorrect arn' do
      it 'responds with a parameter missing error' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic2'],
                      'region' => 'us-gov-west-1') do
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(true)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  context 'with a notification message type' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    # rubocop:disable Layout/LineLength
    let(:headers) do
      {
        'x-amz-sns-message-type' => 'Notification',
        'x-amz-sns-message-id' => 'da41e39f-ea4d-435a-b922-c6aae3915ebe',
        'x-amz-sns-topic-arn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'x-amz-sns-subscription-arn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic:2bcfbf39-05c3-41de-beaa-fcfcc21c8f55',
        'Content-Length' => '761',
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Host' => 'www.example.com',
        'Connection' => 'Keep-Alive',
        'User-Agent' => 'Amazon Simple Notification Service Agent'
      }
    end

    let(:body) do
      {
        'Type' => 'Notification',
        'MessageId' => 'da41e39f-ea4d-435a-b922-c6aae3915ebe',
        'TopicArn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Subject' => 'test',
        'Message' => "{\"Records\":[{\"eventVersion\":\"2.0\",\"eventSource\":\"aws:s3\",\"awsRegion\":\"us-east-1\",\"eventTime\":\"1970-01-01T00:00:00.000Z\",\"eventName\":\"ObjectCreated:Put\",\"userIdentity\":{\"principalId\":\"AIDAJDPLRKLG7UEXAMPLE\"},\"requestParameters\":{\"sourceIPAddress\":\"127.0.0.1\"},\"responseElements\":{\"x-amz-request-id\":\"C3D13FE58DE4C810\",\"x-amz-id-2\":\"FMyUVURIY8/IgAtTv8xRjskZQpcIZ9KG4V5Wp6S7S/JRWeUWerMUE5JgHvANOjpD\"},\"s3\":{\"s3SchemaVersion\":\"1.0\",\"configurationId\":\"testConfigRule\",\"bucket\":{\"name\":\"mybucket\",\"ownerIdentity\":{\"principalId\":\"A3NL1KOZZKExample\"},\"arn\":\"arn:aws:s3:::mybucket\"},\"object\":{\"key\":\"#{upload.guid}\",\"size\":1024,\"eTag\":\"d41d8cd98f00b204e9800998ecf8427e\",\"versionId\":\"096fKKXTRTtl3on89fVO.nfljtsv6qko\",\"sequencer\":\"0055AED6DCD90281E5\"}}}]}",
        'Timestamp' => '2012-04-25T21:49:25.719Z',
        'SignatureVersion' => '1',
        'Signature' => 'EXAMPLElDMXvB8r9R83tGoNn0ecwd5UjllzsvSvbItzfaMpN2nk5HVSw7XnOn/49IkxDKz8YrlH2qJXj2iZB0Zo2O71c4qQk1fMUDi3LGpij7RCW7AW9vYYsSqIKRnFS94ilu7NFhUzLiieYr4BKHpdTmdD6c0esKEYBpabxDSc=',
        'SigningCertURL' => 'https://sns.us-west-2.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem',
        'UnsubscribeURL' => 'https://sns.us-west-2.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-west-2:123456789012:MyTopic:2bcfbf39-05c3-41de-beaa-fcfcc21c8f55'
      }.to_json
    end

    # rubocop:enable Layout/LineLength

    context 'verified message' do
      it 'queues a processor working on the uploaded object-key' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic'],
                      'region' => 'us-gov-west-1') do
          s3_client = instance_double(Aws::S3::Resource)
          allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
          s3_bucket = instance_double(Aws::S3::Bucket)
          s3_object = instance_double(Aws::S3::Object)
          allow(s3_bucket).to receive(:object).with(upload.guid).and_return(s3_object)
          allow(s3_object).to receive(:exists?).and_return(true)
          allow(s3_client).to receive(:bucket).and_return(s3_bucket)
          expect(VBADocuments::UploadProcessor).to receive(:perform_async)
            .with(upload.guid, { caller: 'VBADocuments::Internal::V1::UploadCompleteController' })
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(true)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:no_content)
          upload.reload
          expect(upload.status).to eq('uploaded')
          # if duplicate notifications occur or the upload processor job kicks in before the notification happens sentry
          # receives exceptions it shouldn't.  We should simply log this and do nothing.  We simulate via a duplicate
          # notification.
          # https://vajira.max.gov/browse/API-12668
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context 'non-verified-message' do
      it 'responds with a message verification error' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic'],
                      'region' => 'us-gov-west-1') do
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(false)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'with incorrect arn' do
      it 'responds with a parameter missing error' do
        with_settings(Settings.vba_documents.sns,
                      'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic2'],
                      'region' => 'us-gov-west-1') do
          verifier = double(Aws::SNS::MessageVerifier)
          allow(verifier).to receive(:authentic?).and_return(true)
          allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
          post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  context 'with any other message type' do
    # rubocop:disable Layout/LineLength
    let(:headers) do
      {
        'x-amz-sns-message-type' => 'OtherMessageType',
        'x-amz-sns-message-id' => '165545c9-2a5c-472c-8df2-7ff2be2b3b1b',
        'x-amz-sns-topic-arn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Content-Length' => '1336',
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Host' => 'example.com',
        'Connection' => 'Keep-Alive',
        'User-Agent' => 'Amazon Simple Notification Service Agent'
      }
    end

    let(:body) do
      {
        'Type' => 'SubscriptionConfirmation',
        'MessageId' => '165545c9-2a5c-472c-8df2-7ff2be2b3b1b',
        'Token' => '2336412f37fb687f5d51e6e241d09c805a5a57b30d712f794cc5f6a988666d92768dd60a747ba6f3beb71854e285d6ad02428b09ceece29417f1f02d609c582afbacc99c583a916b9981dd2728f4ae6fdb82efd087cc3b7849e05798d2d2785c03b0879594eeac82c01f235d0e717736',
        'TopicArn' => 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Message' => 'You have chosen to subscribe to the topic arn:aws:sns:us-west-2:123456789012:MyTopic.\nTo confirm the subscription, visit the SubscribeURL included in this message.',
        'SubscribeURL' => 'https://sns.us-west-2.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn:aws:sns:us-west-2:123456789012:MyTopic&Token=2336412f37fb687f5d51e6e241d09c805a5a57b30d712f794cc5f6a988666d92768dd60a747ba6f3beb71854e285d6ad02428b09ceece29417f1f02d609c582afbacc99c583a916b9981dd2728f4ae6fdb82efd087cc3b7849e05798d2d2785c03b0879594eeac82c01f235d0e717736',
        'Timestamp' => '2012-04-26T20:45:04.751Z',
        'SignatureVersion' => '1',
        'Signature' => 'EXAMPLEpH+DcEwjAPg8O9mY8dReBSwksfg2S7WKQcikcNKWLQjwu6A4VbeS0QHVCkhRS7fUQvi2egU3N858fiTDN6bkkOxYDVrY0Ad8L10Hs3zH81mtnPk5uvvolIC1CXGu43obcgFxeL3khZl8IKvO61GWB6jI9b5+gLPoBc1Q=',
        'SigningCertURL' => 'https://sns.us-west-2.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem'
      }.to_json
    end

    # rubocop:enable Layout/LineLength

    xit 'responds with a parameter missing error' do
      with_settings(Settings.vba_documents.sns,
                    'topic_arns' => ['arn:aws:sns:us-west-2:123456789012:MyTopic'],
                    'region' => 'us-gov-west-1') do
        verifier = double(Aws::SNS::MessageVerifier)
        allow(verifier).to receive(:authentic?).and_return(true)
        allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier)
        post('/services/vba_documents/internal/v1/upload_complete', params: body, headers:)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
