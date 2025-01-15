# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/sponsor_service'

RSpec.describe MebApi::DGI::Forms::Sponsor::Service do
  let(:claimant_id) { 600_000_001 }
  let(:user) { create(:user, :loa3) }
  let(:service) { MebApi::DGI::Forms::Sponsor::Service.new(user) }

  describe '#post_sponsor' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      context 'Toes' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/forms/sponsor_toes') do
            response = service.post_sponsor
            expect(response.status).to eq(201)
            expect(response.sponsors).to eq([{ 'first_name' => 'Rodrigo', 'last_name' => 'Diaz',
                                               'sponsor_relationship' => 'Spouse', 'date_of_birth' => '06/12/1975' }])
          end
        end
      end

      context 'FryDea' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/forms/sponsor_fry_dea') do
            response = service.post_sponsor('FryDea')
            expect(response.status).to eq(201)
            expect(response.sponsors).to eq([{ 'first_name' => 'Wilfred', 'last_name' => 'Brimley',
                                               'sponsor_relationship' => 'Spouse', 'date_of_birth' => '06/12/1975' }])
          end
        end
      end
    end
  end
end
