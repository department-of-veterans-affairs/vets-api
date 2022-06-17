# frozen_string_literal: true

require 'rails_helper'
require 'dgi/toe/service'

RSpec.describe MebApi::DGI::Toe::Service do
  let(:claimant_id) { 600_000_001 }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Toe::Service.new(user) }

  describe '#get_toe_letter' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/get_toe_letter') do
          response = service.get_toe_letter(claimant_id)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
