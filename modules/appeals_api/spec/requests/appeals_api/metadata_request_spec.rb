# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/health_checker'

describe AppealsApi::MetadataController, type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:cache) { Rails.cache }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_resource) { instance_double(Aws::S3::Resource) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    allow(Aws::S3::Resource).to receive(:new).with(anything).and_return(s3_resource)
    allow(s3_resource).to receive(:client).and_return(s3_client)
  end

  RSpec.shared_examples 'a healthcheck' do |path|
    it 'returns a successful healthcheck' do
      # stub successful s3 up call
      allow(s3_client).to receive(:head_bucket).with(anything).and_return(true)

      get path

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(parsed_response['description']).to eq('Appeals API health check')
      expect(parsed_response['status']).to eq('pass')
      expect(parsed_response['time']).not_to be_nil
    end
  end

  RSpec.shared_examples 'a failed healthcheck' do |path|
    let(:messenger_instance) { instance_double(AppealsApi::Slack::Messager) }

    it 'returns a failed healthcheck due to s3' do
      # Slack notification expected
      expected_notify = { class: 'AppealsApi::MetadataController',
                          warning: ':warning: ' \
                                   'Appeals API healthcheck failed: unable to connect to AWS S3 bucket.' }
      expect(AppealsApi::Slack::Messager).to receive(:new).with(expected_notify).and_return(messenger_instance)
      expect(messenger_instance).to receive(:notify!).once

      # stub failed s3 up call
      expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)

      get path

      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:service_unavailable)
      expect(parsed_response['description']).to eq('Appeals API health check')
      expect(parsed_response['status']).to eq('fail')
      expect(parsed_response['time']).not_to be_nil
    end

    it 'saves last healthcheck fail slack notify timestamp in redis' do
      expect(AppealsApi::Slack::Messager).to receive(:new).and_return(messenger_instance)
      expect(messenger_instance).to receive(:notify!).once
      expect_any_instance_of(AppealsApi::MetadataController).to receive(:s3_is_healthy?).and_return(false)
      Timecop.freeze do
        last_notify_timestamp = Rails.cache.read(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS)
        expect(last_notify_timestamp).to equal(nil)

        get path

        # confirm that the above slack notification had it's send timestamp recorded in the cache
        last_notify_timestamp = Rails.cache.read(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS)
        expect(last_notify_timestamp).to equal(Time.zone.now.to_i)
      end
    end

    it 'does not send slack notification when s3 is unavailable but slack has already reported recently' do
      Rails.cache.write(described_class::REDIS_LAST_SLACK_NOTIFICATION_TS, Time.zone.now.to_i)

      # stub failed s3 up call
      expect(s3_client).to receive(:head_bucket).with(anything).and_raise(StandardError)
      allow(Aws::S3::Resource).to receive(:new).with(anything).and_return(s3_resource)

      # expect NO slack notification
      expect(AppealsApi::Slack::Messager).not_to receive(:new)

      get path
    end
  end

  RSpec.shared_examples 'an upstream healthcheck (caseflow)' do |path|
    it 'returns a successful healthcheck' do
      VCR.use_cassette 'caseflow/health-check' do
        get path

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API upstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Caseflow')
        expect(upstream_service['status']).to eq('UP')
        expect(upstream_service['details']['name']).to eq('Caseflow')
        expect(upstream_service['details']['statusCode']).to eq(200)
        expect(upstream_service['details']['status']).to eq('OK')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end
    end

    it 'returns correct status when caseflow is not healthy' do
      VCR.use_cassette('caseflow/health-check-down') do
        get path

        expect(response).to have_http_status(:service_unavailable)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API upstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Caseflow')
        expect(upstream_service['status']).to eq('DOWN')
        expect(upstream_service['details']['name']).to eq('Caseflow')
        expect(upstream_service['details']['statusCode']).to eq(503)
        expect(upstream_service['details']['status']).to eq('Unavailable')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end
    end
  end

  RSpec.shared_examples 'an upstream healthcheck (central mail)' do |path|
    it 'returns correct status when CentralMail is healthy' do
      VCR.use_cassette('caseflow/health-check') do
        allow(CentralMail::Service).to receive(:service_is_up?).and_return(true)

        get path

        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API upstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        expect(details['upstreamServices'].size).to eq(1)
        upstream_service = details['upstreamServices'].first
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('UP')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(200)
        expect(upstream_service['details']['status']).to eq('OK')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end
    end

    it 'returns the correct status when CentralMail is not healthy' do
      VCR.use_cassette('caseflow/health-check') do
        allow(CentralMail::Service).to receive(:service_is_up?).and_return(false)

        get path
        expect(response).to have_http_status(:service_unavailable)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API upstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        expect(details['upstreamServices'].size).to eq(1)
        upstream_service = details['upstreamServices'].first
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('DOWN')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(503)
        expect(upstream_service['details']['status']).to eq('Unavailable')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end
    end
  end

  context 'Appeals Metadata Endpoint', type: :request do
    describe '#get /metadata' do
      it 'returns decision reviews metadata JSON' do
        get '/services/appeals/decision_reviews/metadata'
        expect(response).to have_http_status(:ok)
        JSON.parse(response.body)
      end

      it 'returns appeals status metadata JSON' do
        get '/services/appeals/appeals_status/metadata'
        expect(response).to have_http_status(:ok)
        JSON.parse(response.body)
      end
    end

    describe '#healthcheck' do
      context 'v0' do
        it_behaves_like 'a healthcheck', '/services/appeals/v0/healthcheck'
      end

      context 'v1' do
        it_behaves_like 'a healthcheck', '/services/appeals/v1/healthcheck'
      end

      context 'segmented APIs' do
        it_behaves_like 'a healthcheck', '/services/appeals/higher-level-reviews/v0/healthcheck'
        it_behaves_like 'a healthcheck', '/services/appeals/notice-of-disagreements/v0/healthcheck'
        it_behaves_like 'a healthcheck', '/services/appeals/supplemental-claims/v0/healthcheck'
        it_behaves_like 'a healthcheck', '/services/appeals/appealable-issues/v0/healthcheck'
        it_behaves_like 'a healthcheck', '/services/appeals/legacy-appeals/v0/healthcheck'
      end
    end

    describe '#failed_healthcheck' do
      it_behaves_like 'a failed healthcheck', '/services/appeals/v1/healthcheck'
      it_behaves_like 'a failed healthcheck', '/services/appeals/v2/decision_reviews/healthcheck'
      it_behaves_like 'a failed healthcheck', '/services/appeals/notice-of-disagreements/v0/healthcheck'
      it_behaves_like 'a failed healthcheck', '/services/appeals/supplemental-claims/v0/healthcheck'
    end

    describe '#upstream_healthcheck' do
      before do
        time = Time.utc(2020, 9, 21, 0, 0, 0)
        Timecop.freeze(time)
      end

      after { Timecop.return }

      context 'v0' do
        it_behaves_like 'an upstream healthcheck (caseflow)', '/services/appeals/v0/upstream_healthcheck'
      end

      context 'decision reviews v2' do
        it 'checks the status of both services individually' do
          VCR.use_cassette('caseflow/health-check') do
            allow(CentralMail::Service).to receive(:service_is_up?).and_return(false)

            get '/services/appeals/v2/decision_reviews/upstream_healthcheck'
            parsed_response = JSON.parse(response.body)

            caseflow = parsed_response['details']['upstreamServices'].first
            central_mail = parsed_response['details']['upstreamServices'].last

            expect(response).to have_http_status(:service_unavailable)
            expect(caseflow['status']).to eq('UP')
            expect(central_mail['status']).to eq('DOWN')
          end
        end

        it 'returns correct response and status when healthy' do
          VCR.use_cassette('caseflow/health-check') do
            allow(CentralMail::Service).to receive(:service_is_up?).and_return(true)

            get '/services/appeals/v2/decision_reviews/upstream_healthcheck'
            expect(response).to have_http_status(:ok)

            parsed_response = JSON.parse(response.body)
            expect(parsed_response['description']).to eq('Appeals API upstream health check')
            expect(parsed_response['status']).to eq('UP')
            expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

            details = parsed_response['details']
            expect(details['name']).to eq('All upstream services')

            upstream_service = details['upstreamServices'].first
            expect(details['upstreamServices'].size).to eq(2)
            expect(upstream_service['description']).to eq('Caseflow')
            expect(upstream_service['status']).to eq('UP')
            expect(upstream_service['details']['name']).to eq('Caseflow')
            expect(upstream_service['details']['statusCode']).to eq(200)
            expect(upstream_service['details']['status']).to eq('OK')
            expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
          end
        end

        it 'returns correct status when caseflow is not healthy' do
          VCR.use_cassette('caseflow/health-check-down') do
            allow(CentralMail::Service).to receive(:service_is_up?).and_return(true)

            get '/services/appeals/v2/decision_reviews/upstream_healthcheck'
            expect(response).to have_http_status(:service_unavailable)

            parsed_response = JSON.parse(response.body)
            expect(parsed_response['description']).to eq('Appeals API upstream health check')
            expect(parsed_response['status']).to eq('DOWN')
            expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

            details = parsed_response['details']
            expect(details['name']).to eq('All upstream services')

            upstream_service = details['upstreamServices'].first
            expect(details['upstreamServices'].size).to eq(2)
            expect(upstream_service['description']).to eq('Caseflow')
            expect(upstream_service['status']).to eq('DOWN')
            expect(upstream_service['details']['name']).to eq('Caseflow')
            expect(upstream_service['details']['statusCode']).to eq(503)
            expect(upstream_service['details']['status']).to eq('Unavailable')
            expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
          end
        end

        it 'returns the correct status when CentralMail is not healthy' do
          VCR.use_cassette('caseflow/health-check') do
            allow(CentralMail::Service).to receive(:service_is_up?).and_return(false)

            get '/services/appeals/v2/decision_reviews/upstream_healthcheck'
            expect(response).to have_http_status(:service_unavailable)

            parsed_response = JSON.parse(response.body)
            expect(parsed_response['description']).to eq('Appeals API upstream health check')
            expect(parsed_response['status']).to eq('DOWN')
            expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

            details = parsed_response['details']
            expect(details['name']).to eq('All upstream services')

            upstream_service = details['upstreamServices'].last
            expect(details['upstreamServices'].size).to eq(2)
            expect(upstream_service['description']).to eq('Central Mail')
            expect(upstream_service['status']).to eq('DOWN')
            expect(upstream_service['details']['name']).to eq('Central Mail')
            expect(upstream_service['details']['statusCode']).to eq(503)
            expect(upstream_service['details']['status']).to eq('Unavailable')
            expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
          end
        end

        it 'returns correct status when CentralMail is healthy' do
          VCR.use_cassette('caseflow/health-check') do
            allow(CentralMail::Service).to receive(:service_is_up?).and_return(true)

            get '/services/appeals/v2/decision_reviews/upstream_healthcheck'
            expect(response).to have_http_status(:ok)

            parsed_response = JSON.parse(response.body)
            expect(parsed_response['description']).to eq('Appeals API upstream health check')
            expect(parsed_response['status']).to eq('UP')
            expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

            details = parsed_response['details']
            expect(details['name']).to eq('All upstream services')

            upstream_service = details['upstreamServices'].last
            expect(details['upstreamServices'].size).to eq(2)
            expect(upstream_service['description']).to eq('Central Mail')
            expect(upstream_service['status']).to eq('UP')
            expect(upstream_service['details']['name']).to eq('Central Mail')
            expect(upstream_service['details']['statusCode']).to eq(200)
            expect(upstream_service['details']['status']).to eq('OK')
            expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
          end
        end
      end

      context 'segmented APIs' do
        it_behaves_like(
          'an upstream healthcheck (central mail)',
          '/services/appeals/supplemental-claims/v0/upstream-healthcheck'
        )
        it_behaves_like(
          'an upstream healthcheck (central mail)',
          '/services/appeals/notice-of-disagreements/v0/upstream-healthcheck'
        )
        it_behaves_like(
          'an upstream healthcheck (central mail)',
          '/services/appeals/higher-level-reviews/v0/upstream-healthcheck'
        )
        it_behaves_like(
          'an upstream healthcheck (caseflow)',
          '/services/appeals/appealable-issues/v0/upstream-healthcheck'
        )
        it_behaves_like(
          'an upstream healthcheck (caseflow)',
          '/services/appeals/legacy-appeals/v0/upstream-healthcheck'
        )
      end
    end
  end
end
