# frozen_string_literal: true

require 'rails_helper'
require 'dgi/exclusion_period/service'

RSpec.describe MebApi::DGI::ExclusionPeriod::Service do
  include ActiveSupport::Testing::TimeHelpers
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end

    let(:claimant_id) { 600_010_259 }
    let(:user) { create(:user, :loa3) }
    let(:service) { MebApi::DGI::ExclusionPeriod::Service.new(user) }

    describe '#get_exclusion_periods' do
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'when successful' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/get_exclusion_period_serivce') do
            travel_to Time.zone.local(2022, 2, 9, 12) do
              response = service.get_exclusion_periods(claimant_id)
              expect(response.status).to eq(200)
            end
          end
        end
      end
    end
  end
end
