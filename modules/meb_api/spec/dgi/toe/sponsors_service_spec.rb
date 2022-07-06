# frozen_string_literal: true

require 'rails_helper'
require 'dgi/toe/sponsors_service'

RSpec.describe MebApi::DGI::Toe::Sponsor::Service do
  let(:claimant_id) { 600_000_001 }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Toe::Sponsor::Service.new(user) }

  describe '#post_sponsor' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/post_sponsor') do
          response = service.post_sponsor
          expect(response.status).to eq(201)
          expect(response.sponsors).to eq([{ 'first_name' => 'Rodrigo', 'last_name' => 'Diaz',
                                             'sponsor_relationship' => '', 'date_of_birth' => '06/12/1975' }])
        end
      end
    end
  end
end
