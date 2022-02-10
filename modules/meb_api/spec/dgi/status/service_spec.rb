# frozen_string_literal: true

require 'rails_helper'
require 'dgi/status/service'

RSpec.describe MebApi::DGI::Status::Service do
  let(:claimant_id) { 99_900_000_200_000_000 }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Status::Service.new(user) }

  describe '#get_claim_status' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/get_claim_status') do
          response = service.get_claim_status(claimant_id)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
