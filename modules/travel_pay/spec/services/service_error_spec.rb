# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ServiceError do
  context 'raises error from error map' do
    msg = 'Not found'
    status_code = 404

    let(:error) do
      env = Faraday::Env.new.tap do |e|
        e.status = status_code
        e.body = "{\"message\": \"#{msg}\"}"
      end

      err = Faraday::Error.new(msg, env)
      allow(err).to receive_messages(response_status: status_code, response_body: JSON.parse(env.body))

      err
    end

    it 'returns expected response' do
      expect { TravelPay::ServiceError.raise_mapped_error(error) }.to raise_error(
        Common::Exceptions::ResourceNotFound
      ) do |e|
        expect(e.errors.first[:title]).to eq(msg)
        expect(e.errors.first[:status]).to eq(status_code)
      end
    end
  end

  context 'raises custom error for nil response body' do
    msg = 'There was a problem'
    let(:error) do
      env = Faraday::Env.new.tap do |e|
        e.status = 500
        e.define_singleton_method(:response_body) { nil }
      end
      Faraday::Error.new(msg, env)
    end

    it 'returns expected response' do
      expect(Rails.logger).to receive(:error).with(
        message: 'raise_mapped_error received nil response_body. ' \
                 "status: #{error.response_status}, " \
                 "returning 500. message: #{error.message}"
      )

      expect { TravelPay::ServiceError.raise_mapped_error(error) }.to raise_error(
        Common::Exceptions::ServiceError
      ) do |e|
        expect(e.errors.first[:title]).to eq(msg)
        expect(e.errors.first[:status]).to eq(500)
      end
    end
  end
end
