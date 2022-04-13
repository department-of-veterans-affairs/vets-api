# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FitbitService, type: :service do
  subject { described_class.new }

  describe 'fitbit#get_connection_status' do
    fitbit_client = DhpConnectedDevices::Fitbit::Client.new
    fitbit_code = '406352'
    context 'either error_detail or error included in Fitbit callback params' do
      it "returns 'error'" do
        errors = %w[error_detail error]
        errors.each do |param|
          status = subject.get_connection_status({ callback_params: { param => 'declined' },
                                                   fitbit_api: fitbit_client })
          expect(status).to eq('error')
        end
      end
    end

    context 'no code is included in Fitbit response' do
      it "returns 'error'" do
        status = subject.get_connection_status({ callback_params: {}, fitbit_api: fitbit_client })
        expect(status).to eq 'error'
      end
    end

    context 'auth code is included in Fitbit response and token exchange is successful' do
      before do
        faraday_response = double('response', status: 200)
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it "returns 'success'" do
        status = subject.get_connection_status({ callback_params: { code: fitbit_code }, fitbit_api: fitbit_client })
        expect(status).to eq 'success'
      end
    end

    context 'auth code is included in Fitbit response and token exchange fails' do
      before do
        faraday_response = double('response', status: 400)
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it "returns 'error'" do
        status = subject.get_connection_status({ callback_params: { code: fitbit_code }, fitbit_api: fitbit_client })
        expect(status).to eq 'error'
      end
    end
  end
end
