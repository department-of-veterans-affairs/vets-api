# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/health_checker'

Rspec.describe VBADocuments::MetadataController, type: :request do
  describe '#healthcheck' do
    context 'v1' do
      let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
      let(:cache) { Rails.cache }
      let(:messenger_instance) { instance_double(VBADocuments::Slack::Messenger) }
      let(:s3_resource) { instance_double(Aws::S3::Resource) }
      let(:s3_client) { instance_double(Aws::S3::Client) }
      let(:expected_notify) do
        { class: 'VBADocuments::MetadataController',
          warning: ':vertical_traffic_light: ' \
                   'Benefits Intake healthcheck failed: unable to connect to AWS S3 bucket.' }
      end

      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear

        allow(Aws::S3::Resource).to receive(:new).with(anything).and_return(s3_resource)
        allow(s3_resource).to receive(:client).and_return(s3_client)
      end

      it 'returns a successful health check' do
        allow(s3_client).to receive(:head_bucket).with(anything).and_return(true)

        get '/services/vba_documents/v1/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['description']).to eq('VBA Documents API health check')
        expect(parsed_response['status']).to eq('pass')
        expect(parsed_response['time']).not_to be_nil
      end

      it 'returns a failed health check when s3 is unavailable' do
        expect(VBADocuments::Slack::Messenger).to receive(:new).with(expected_notify).and_return(messenger_instance)
        expect(messenger_instance).to receive(:notify!).once
        expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)

        get '/services/vba_documents/v1/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:service_unavailable)
        expect(parsed_response['description']).to eq('VBA Documents API health check')
        expect(parsed_response['status']).to eq('fail')
        expect(parsed_response['time']).not_to be_nil
      end

      it 'saves last healthcheck fail slack notify timestamp in redis' do
        expect(VBADocuments::Slack::Messenger).to receive(:new).with(expected_notify).and_return(messenger_instance)
        expect(messenger_instance).to receive(:notify!).once
        expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)

        Timecop.freeze do
          last_notify_timestamp = Rails.cache.read(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS)
          expect(last_notify_timestamp).to equal(nil)

          get '/services/vba_documents/v1/healthcheck'

          # confirm that the above slack notification had it's send timestamp recorded in the cache
          last_notify_timestamp = Rails.cache.read(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS)
          expect(last_notify_timestamp).to equal(Time.zone.now.to_i)
        end
      end

      it 'returns a failed health check when slack is down' do
        expect(VBADocuments::Slack::Messenger).to receive(:new).with(expected_notify).and_return(messenger_instance)
        se = StandardError.new
        expect(messenger_instance).to receive(:notify!).once.and_raise(se)
        expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)
        expect(Rails.logger).to receive(:error).with('Benefits Intake S3 failed Healthcheck slack notification ' \
                                                     'failed: StandardError', se)

        get '/services/vba_documents/v1/healthcheck'

        expect(response).to have_http_status(:service_unavailable)
      end

      it 'does not send slack notification when s3 is unavailable but slack has already reported recently' do
        Rails.cache.write(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS, Time.zone.now.to_i)
        expect(VBADocuments::Slack::Messenger).not_to receive(:new)
        expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)

        get '/services/vba_documents/v1/healthcheck'
      end
    end
  end

  describe '#upstream_healthcheck' do
    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    context 'v1' do
      it 'returns correct response and status when healthy' do
        allow(Breakers::Outage).to receive(:find_latest).and_return(nil)
        get '/services/vba_documents/v1/upstream_healthcheck'
        expect(response).to have_http_status(:ok)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('UP')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(200)
        expect(upstream_service['details']['status']).to eq('OK')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end

      it 'returns correct status when central_mail is not healthy' do
        allow(Breakers::Outage).to receive(:find_latest).and_return(OpenStruct.new(start_time: Time.zone.now))
        allow_any_instance_of(CentralMail::Service).to receive(:status).and_return(OpenStruct.new(status: 503))
        get '/services/vba_documents/v1/upstream_healthcheck'
        expect(response).to have_http_status(:service_unavailable)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('DOWN')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(503)
        expect(upstream_service['details']['status']).to eq('Unavailable')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end
    end
  end
end
