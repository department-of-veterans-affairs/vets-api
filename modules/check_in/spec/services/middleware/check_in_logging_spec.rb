# frozen_string_literal: true

require 'rails_helper'

Faraday::Middleware.register_middleware(check_in_logging: Middleware::CheckInLogging)
Faraday::Response.register_middleware(check_in_errors: Middleware::Errors)

describe Middleware::CheckInLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :check_in_logging

      conn.adapter :test do |stub|
        stub.post(chip_token_req) { [status, { 'x-apigw-api-id' => '2dcdrrn5zc' }, sample_jwt] }
      end
    end
  end

  let(:chip_token_req) do
    'https://vpce-06399548ef94bdb41-lk4qp2nd.execute-api.us-gov-west-1.vpce.amazonaws.com/dev/token'
  end
  let(:sample_jwt) do
    {
      'token' => 'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj'
    }.to_json
  end

  describe '#call' do
    let(:log_tags) do
      {
        status:,
        duration: 0.0
      }
    end

    context 'when status 200' do
      let(:status) { 200 }

      it 'rails logger should receive the success log tags' do
        url = { url: "(POST) #{chip_token_req}" }

        Timecop.freeze(Time.current) do
          expect(Rails.logger).to receive(:info)
            .with('CheckIn service call succeeded!', log_tags.merge(url)).and_call_original

          client.post(chip_token_req)
        end
      end
    end

    context 'when not success status' do
      let(:status) { 500 }

      it 'rails logger should receive the failed log tags' do
        url = { url: "(POST) #{chip_token_req}" }
        Timecop.freeze(Time.current) do
          expect(Rails.logger).to receive(:warn)
            .with('CheckIn service call failed!', log_tags.merge(url)).and_call_original

          client.post(chip_token_req)
        end
      end
    end
  end
end
