# frozen_string_literal: true

require 'rails_helper'
require 'lgy/service'

RSpec.describe LGY::Service do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:service) { LGY::Service.new(edipi: user.edipi, icn: user.icn) }

  describe '#get_coe_status' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with an eligible determination' do
      it 'successfully receives an eligible determination' do
        VCR.use_cassette('lgy/determination_eligible') do
          response = service.get_determination

          expect(response.status).to eq(200)
          expect(response.body['status']).to eq('ELIGIBLE')
          expect(response.body['reference_number']).to eq('16934344')
          # rubocop:disable Style/NumericLiterals
          expect(response.body['determination_date']).to eq(1638569892000)
          # rubocop:enable Style/NumericLiterals
        end
      end
    end

    context 'with an automatically approved coe' do
      it 'does not find an application' do
        VCR.use_cassette('lgy/application_not_found') do
          response = service.get_application

          expect(response.status).to eq(404)
          expect(response.body['status']).to eq(404)
          expect(response.body.key?('lgy_request_uuid')).to eq(true)
          expect(response.body['errors'][0]['message']).to eq('Not Found')
        end
      end
    end
  end
end
