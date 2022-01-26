# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/service'

RSpec.describe MebApi::DGI::Enrollment::Service do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Enrollment::Service.new(user) }

  describe '#get_claim_letter' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/get_claim_letter') do
          response = service.get_enrollment
          expect(response).to eq(true)
        end
      end
    end
  end
end
