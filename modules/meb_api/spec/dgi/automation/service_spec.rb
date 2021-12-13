# frozen_string_literal: true

require 'rails_helper'
require 'dgi/automation/service'

Rspec.describe MebApi::DGI::Automation::Service do
  let(:user_details) do
    {
      first_name: 'Herbert',
      last_name: 'Hoover',
      middle_name: '',
      birth_date: '1970-01-01',
      ssn: '539139735'
    }
  end

  let(:user) { FactoryBot.create(:user, :loa3, user_details) }
  let(:service) { MebApi::DGI::Automation::Service.new(user) }

  describe '#post_claimant_info' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission and info exists' do
      it 'successfully receives an Claimant object' do
        VCR.use_cassette('dgi/post_claimant_info') do
          response = service.get_claimant_info

          expect(response.status).to eq(201)
          expect(response['claimant']['claimant_id']).to eq(1_000_000_000_000_261)
        end
      end
    end
  end
end
