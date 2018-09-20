# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PerformanceMonitorings', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    allow_any_instance_of(User).to receive(:icn).and_return('1234')
  end

  describe 'POST /v0/performance_monitorings' do
    let(:body) {
      {
        metric: 'initial_page_load',
        duration: 100.1,
        page_id: 'some_unique_page_identifier'
      }
    }

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
  end
end
