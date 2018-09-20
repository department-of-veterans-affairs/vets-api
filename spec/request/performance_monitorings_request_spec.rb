# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'PerformanceMonitorings', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    allow_any_instance_of(User).to receive(:icn).and_return('1234')
  end

  describe 'POST /v0/performance_monitorings' do
    let(:body) do
      {
        page_id: 'some_unique_page_identifier',
        metrics: [
          { metric: 'initial_page_load', duration: 1234.56 },
          { metric: 'time_to_paint', duration: 123.45 }
        ]
      }
    end

    context 'with a 200 response' do
      it 'should match the performance monitoring schema', :aggregate_failures do
        post(
          '/v0/performance_monitorings',
          body.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('performance_monitoring')
      end
    end

    context 'with a missing parameter' do
      let(:body_missing_param) do
        {
          page_id: 'some_unique_page_identifier',
          metrics: [
            { metric: 'initial_page_load', duration: 1234.56 },
            { metric: 'time_to_paint', duration: nil }
          ]
        }
      end

      it 'should match the errors schema', :aggregate_failures do
        post(
          '/v0/performance_monitorings',
          body_missing_param.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        body = JSON.parse(response.body)
        error_keys = body.dig('errors').first.keys

        expect(response).to have_http_status(:bad_request)
        expect(error_keys).to include 'title', 'detail', 'code', 'status'
      end
    end
  end
end
