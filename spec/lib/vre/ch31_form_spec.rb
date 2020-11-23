# frozen_string_literal: true

require 'rails_helper'
require 'vre/ch31_form'

RSpec.describe VRE::Ch31Form do
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:service) { VRE::Ch31Form.new(user, claim) }
  let(:new_address_hash) do
    {
      newAddress: {
        isForeign: false,
        isMilitary: nil,
        countryName: 'USA',
        addressLine1: '1019 Robin Cir',
        addressLine2: nil,
        addressLine3: nil,
        city: 'Arroyo Grande',
        province: 'CA',
        internationalPostalCode: '93420'
      }
    }
  end

  describe '#submit' do
    let(:faraday_response) { double('faraday_connection') }
    before(:each) do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully sends to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          # allow_any_instance_of(Faraday::Env).to receive(:body) { "{\"ErrorOccurred\":false,\"ApplicationIntake\":\"12345\"}" }

          response = service.submit

          expect(response['error_occurred']).to eq(false)
        end
      end

      it 'adds a new address if the user is moving within 30 days' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect(service).to receive(:new_address) { new_address_hash }

          service.submit
        end
      end

      it 'does not successfully send to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_vre' do
          response = service.submit

          expect(response['error_occurred']).to eq(true)
        end
      end
    end
  end
end
