# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'PerformanceMonitorings', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:header) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:whitelisted_path) { Benchmark::Whitelist::WHITELIST.first }

  describe 'POST /v0/performance_monitorings' do
    let(:body) do
      {
        data: {
          page_id: whitelisted_path,
          metrics: [
            { metric: 'totalPageLoad', duration: 1234.56 },
            { metric: 'firstContentfulPaint', duration: 123.45 }
          ]
        }.to_json
      }
    end

    context 'with a 200 response' do
      it 'should match the performance monitoring schema', :aggregate_failures do
        post('/v0/performance_monitorings', params: body.to_json, headers: header)

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('performance_monitoring')
      end
    end

    context 'with a missing parameter' do
      let(:body_missing_param) do
        {
          data: {
            page_id: whitelisted_path,
            metrics: [
              { metric: 'totalPageLoad', duration: 1234.56 },
              { metric: 'firstContentfulPaint', duration: nil }
            ]
          }.to_json
        }
      end

      it 'should match the errors schema', :aggregate_failures do
        post('/v0/performance_monitorings', params: body_missing_param.to_json, headers: header)

        body = JSON.parse(response.body)
        error_keys = body.dig('errors').first.keys

        expect(response).to have_http_status(:bad_request)
        expect(error_keys).to include 'title', 'detail', 'code', 'status'
      end
    end

    context 'with a non-whitelisted tag' do
      let(:non_whitelisted_tag) { 'some_random_tag' }
      let(:non_whitelisted_body) do
        {
          data: {
            page_id: non_whitelisted_tag,
            metrics: [
              { metric: 'totalPageLoad', duration: 1234.56 },
              { metric: 'firstContentfulPaint', duration: 123.45 }
            ]
          }.to_json
        }
      end

      it 'should match the errors schema', :aggregate_failures do
        post('/v0/performance_monitorings', params: non_whitelisted_body.to_json, headers: header)

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('errors')
      end
    end
  end
end
