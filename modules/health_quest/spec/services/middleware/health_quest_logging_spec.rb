# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/health_fixture_helper'

describe HealthQuest::Middleware::HealthQuestLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :health_quest_logging

      conn.adapter :test do |stub|
        stub.post(health_token_req) { [status, { 'Content-Type' => 'application/x-www-form-urlencoded' }, sample_jwt] }
        stub.post(pgd_token_req) { [status, { 'Content-Type' => 'application/x-www-form-urlencoded' }, sample_jwt] }
      end
    end
  end

  let(:health_token_req) { 'https://sandbox-api.va.gov/oauth2/health/system/v1/token' }
  let(:pgd_token_req) { 'https://sandbox-api.va.gov/pgd/v1/token' }
  let(:sample_jwt) { { 'access_token' => HealthFixtureHelper.read_fixture_file('sample_jwt.response') }.to_json }
  let(:jwt_id) { 'ebfc95ef5f3a41a7b15e432fe47e9864' }

  before do
    Timecop.freeze
  end

  after { Timecop.return }

  describe '#call' do
    let(:log_tags) do
      {
        jti: jwt_id,
        status:,
        duration: 0.0
      }
    end

    context 'when status 200' do
      let(:status) { 200 }

      it 'rails logger should receive the success log tags' do
        [health_token_req, pgd_token_req].each do |token_request|
          url = { url: "(POST) #{token_request}" }

          expect(Rails.logger).to receive(:info)
            .with('HealthQuest service call succeeded!', log_tags.merge(url)).and_call_original

          client.post(token_request)
        end
      end
    end

    context 'when not success status' do
      let(:status) { 500 }

      it 'rails logger should receive the failed log tags' do
        [health_token_req, pgd_token_req].each do |token_request|
          url = { url: "(POST) #{token_request}" }

          expect(Rails.logger).to receive(:warn)
            .with('HealthQuest service call failed!', log_tags.merge(url)).and_call_original

          client.post(token_request)
        end
      end
    end
  end
end
