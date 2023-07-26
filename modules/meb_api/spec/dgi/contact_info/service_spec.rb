# frozen_string_literal: true

require 'rails_helper'
require 'dgi/contact_info/service'

Rspec.describe MebApi::DGI::ContactInfo::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end

    describe '#check_for_duplicates' do
      let(:user_contact_info) do
        {
          emails: ['test@test.com'],
          phones: ['8013090123']
        }
      end

      let(:user) { FactoryBot.create(:user, :loa3) }
      let(:service) { MebApi::DGI::ContactInfo::Service.new(user) }
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'with a successful submission' do
        it 'successfully receives information on submitted contact info' do
          VCR.use_cassette('dgi/post_contact_info') do
            response = service.check_for_duplicates(user_contact_info[:emails], user_contact_info[:phones])
            expect(response.status).to eq(200)

            expect(response.email[0]['dupe']).to eq('false')
            expect(response.phone[0]['dupe']).to eq('false')
          end
        end
      end
    end
  end
end
