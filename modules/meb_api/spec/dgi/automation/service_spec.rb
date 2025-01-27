# frozen_string_literal: true

require 'rails_helper'
require 'dgi/automation/service'

Rspec.describe MebApi::DGI::Automation::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end

    describe '#post_claimant_info for Chapter33' do
      let(:user_details) do
        {
          first_name: 'Herbert',
          last_name: 'Hoover',
          middle_name: '',
          birth_date: '1970-01-01',
          ssn: '796126859'
        }
      end

      let(:user) { create(:user, :loa3, user_details) }
      let(:service) { MebApi::DGI::Automation::Service.new(user) }
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'with a successful submission and info exists for Chapter33' do
        it 'successfully receives an Claimant object' do
          VCR.use_cassette('dgi/post_claimant_info') do
            response = service.get_claimant_info('Chapter33')
            expect(response.status).to eq(201)
            expect(response['claimant']['claimant_id']).to eq(600_010_259)
          end
        end
      end
    end
  end
end
