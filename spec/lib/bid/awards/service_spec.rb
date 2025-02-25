# frozen_string_literal: true

require 'rails_helper'
require 'bid/awards/service'

RSpec.describe BID::Awards::Service do
  let(:user) { create(:evss_user, :loa3) }
  let(:service) { BID::Awards::Service.new(user) }

  describe '#get_awards_pension' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully receives an Award Pension object' do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          response = service.get_awards_pension

          expect(response.status).to eq(200)
          expect(response.body['awards_pension']['is_eligible_for_pension']).to be(true)
          expect(response.body['awards_pension']['is_in_receipt_of_pension']).to be(true)
        end
      end
    end
  end
end
