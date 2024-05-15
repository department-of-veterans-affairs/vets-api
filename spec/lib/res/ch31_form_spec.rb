# frozen_string_literal: true

require 'rails_helper'
require 'res/ch31_form'

RSpec.describe RES::Ch31Form do
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:service) { RES::Ch31Form.new(user:, claim:) }
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

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully sends to RES' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_res' do
          response = service.submit
          expect(response['error_occurred']).to eq(false)
        end
      end

      it 'adds a new address if the user is moving within 30 days' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_res' do
          expect(service).to receive(:new_address) { new_address_hash }

          service.submit
        end
      end
    end

    context 'with an unsuccessful submission' do
      it 'does not successfully send to RES' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_res' do
          expect(service).to receive(:log_exception_to_sentry)

          response = service.submit

          expect(response['error_occurred']).to eq(true)
        end
      end

      it 'handles nil claim' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_res' do
          nil_claim_service = RES::Ch31Form.new(user:, claim: nil)
          expect(nil_claim_service).to receive(:log_exception_to_sentry)

          response = nil_claim_service.submit

          expect(response['error_occurred']).to eq(true)
        end
      end
    end
  end
end
