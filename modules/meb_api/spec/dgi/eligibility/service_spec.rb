# frozen_string_literal: true

require 'rails_helper'
require 'dgi/eligibility/service'

RSpec.describe MebApi::DGI::Eligibility::Service do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Eligibility::Service.new(user) }

  describe '#get_eligibility' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/get_eligibility') do
          response = service.get_eligibility
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
