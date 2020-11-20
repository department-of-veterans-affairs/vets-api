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

    context 'with a successful submission' do
      it 'successfully sends to VRE' do
        allow(faraday_response).to receive(:body).and_return('{"ErrorOccurred":false,"ApplicationIntake":"12345"}')
        allow_any_instance_of(Faraday::Connection).to receive(:post) { faraday_response }

        response = service.submit
        expect(response).to eq(true)
      end

      it 'adds a new address if the user is moving within 30 days' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect(service).to receive(:new_address) { new_address_hash }

          service.submit
        end
      end

      it 'does not successfully send to VRE' do
        allow(faraday_response).to receive(:body).and_return(
          '{"ErrorOccurred":true,"ErrorMessage":"bad stuff happened"}'
        )

        allow_any_instance_of(Faraday::Connection).to receive(:post) { faraday_response }
        expect(service).to receive(:log_exception_to_sentry)

        service.submit
      end
    end
  end
end
