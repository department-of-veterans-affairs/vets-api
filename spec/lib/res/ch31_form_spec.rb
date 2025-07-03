# frozen_string_literal: true

require 'rails_helper'
require 'res/ch31_form'

RSpec.describe RES::Ch31Form do
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:claim_with_new_form) { create(:new_veteran_readiness_employment_claim) }
  let(:claim_with_new_form_minimal) { create(:new_veteran_readiness_employment_claim_minimal) }
  let(:user) { create(:evss_user, :loa3) }
  let(:service) { RES::Ch31Form.new(user:, claim:) }
  let(:service_with_new_form) { RES::Ch31Form.new(user:, claim: claim_with_new_form) }
  let(:service_with_new_form_minimal) { RES::Ch31Form.new(user:, claim: claim_with_new_form_minimal) }
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
  let(:success_message) { OpenStruct.new(body: { 'success_message' => 'RES has successfully received the request' }) }

  describe '#submit' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful old form submission' do
      before do
        allow(service).to receive(:send_to_res).and_return(success_message)
      end

      it 'adds a new address if the user is moving within 30 days' do
        expect(service).to receive(:new_address) { new_address_hash }
        service.submit
      end
    end

    context 'with a successful new form submission' do
      it 'adds a new address if the user is moving within 30 days' do
        allow(service_with_new_form).to receive(:send_to_res).and_return(success_message)
        expect(service_with_new_form).to receive(:new_address) { new_address_hash }

        service_with_new_form.submit
      end

      it 'accepts only required fields' do
        allow(service_with_new_form_minimal).to receive(:send_to_res).and_return(success_message)
        expect(service_with_new_form_minimal).to receive(:mapped_address_hash).and_return(nil)

        service_with_new_form_minimal.submit
      end
    end

    context 'with an unsuccessful submission' do
      context 'with old form' do
        it 'does not successfully send to RES' do
          allow(service).to receive(:send_to_res).and_return(OpenStruct.new(body: { 'error' => 'Error' }))
          expect { service.submit }.to raise_error(Ch31Error)
        end
      end

      context 'with new form' do
        it 'does not successfully send to RES' do
          allow(service_with_new_form).to receive(:send_to_res).and_return(OpenStruct.new(body: { 'error' => 'Error' }))
          expect { service_with_new_form.submit }.to raise_error(Ch31Error)
        end
      end

      it 'handles nil claim' do
        nil_claim_service = RES::Ch31Form.new(user:, claim: nil)
        expect { nil_claim_service.submit }.to raise_error(Ch31NilClaimError)
      end
    end
  end
end
