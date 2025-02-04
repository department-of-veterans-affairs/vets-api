# frozen_string_literal: true

require 'rails_helper'
require 'dgi/status/service'

RSpec.describe MebApi::DGI::Status::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
    let(:claimant_id) { 600_000_001 }
    let(:user) { create(:user, :loa3) }
    let(:service) { MebApi::DGI::Status::Service.new(user) }

    describe '#get_claim_status' do
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'when successful' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/get_claim_status') do
            response = service.get_claim_status({}, claimant_id)
            expect(response.status).to eq(200)
          end
        end
      end
    end

    describe '#get_toe_claim_status' do
      let(:faraday_response) { double('faraday_connection') }
      let(:service) { MebApi::DGI::Status::Service.new(user) }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'when successful' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/get_toe_claim_status') do
            response = service.get_claim_status({}, claimant_id, 'toe')
            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
