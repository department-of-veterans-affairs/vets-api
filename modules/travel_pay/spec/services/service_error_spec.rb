# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ServiceError do
  context 'raise_mapped_error' do
    let(:error) do
      env = Faraday::Env.new.tap do |e|
        e.status = 500
        e.define_singleton_method(:response_body) { nil }
      end
      Faraday::Error.new('There was a problem', env)
    end

    it 'returns custom server error if response_body is nil' do
      expect(Rails.logger).to receive(:error).with(
        message: 'raise_mapped_error received nil response_body. ' \
                 "status: #{error.response_status}, " \
                 "returning 500. message: #{error.message}"
      )

      expect { TravelPay::ServiceError.raise_mapped_error(error) }.to raise_error(
        Common::Exceptions::ExternalServerInternalServerError
      ) do |e|
        expect(e.errors.first[:title]).to eq('There was a problem')
        expect(e.errors.first[:status]).to eq(500)
      end
    end
  end
end
