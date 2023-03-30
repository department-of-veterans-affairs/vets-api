# frozen_string_literal: true

require 'rails_helper'
require 'vre/ch31_form'

RSpec.describe VRE::Ch31Form do
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:service) { VRE::Ch31Form.new(user:, claim:) }
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
      it 'successfully sends to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
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
    end

    context 'with an unsuccessful submission' do
      it 'does not successfully send to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_vre' do
          expect(service).to receive(:log_exception_to_sentry)

          response = service.submit

          expect(response['error_occurred']).to eq(true)
        end
      end

      it 'handles nil claim' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_vre' do
          nil_claim_service = VRE::Ch31Form.new(user:, claim: nil)
          expect(nil_claim_service).to receive(:log_exception_to_sentry)

          response = nil_claim_service.submit

          expect(response['error_occurred']).to eq(true)
        end
      end
    end

    context "user's current (veteran) address is foreign" do
      let(:foreign_vet_address_claim) do
        claim = create(:veteran_readiness_employment_claim)
        form_copy = claim.parsed_form
        form_copy['veteranAddress']['country'] = 'DEU'
        claim.form = form_copy.to_json

        claim
      end

      it 'updates veteran address zipCode to internationPostalCode' do
        foreign_vet_address_claim_service = VRE::Ch31Form.new(user:, claim: foreign_vet_address_claim)
        response_double = double('response')

        allow(response_double).to receive(:body).and_return(
          { 'error_occurred' => false, 'application_intake' => '12345' }
        )

        expect(foreign_vet_address_claim_service).to receive(:send_to_vre).with(
          payload: a_string_including('"internationPostalCode":"33928"')
        ) { response_double }

        foreign_vet_address_claim_service.submit
      end

      it 'updates veteran address stateCode to province' do
        foreign_vet_address_claim_service = VRE::Ch31Form.new(user:, claim: foreign_vet_address_claim)
        response_double = double('response')

        allow(response_double).to receive(:body).and_return(
          { 'error_occurred' => false, 'application_intake' => '12345' }
        )

        expect(foreign_vet_address_claim_service).to receive(:send_to_vre).with(
          payload: a_string_including('"province":"FL"')
        ) { response_double }

        foreign_vet_address_claim_service.submit
      end
    end

    context "user's new address is foreign" do
      let(:foreign_new_address_claim) do
        claim = create(:veteran_readiness_employment_claim)
        form_copy = claim.parsed_form
        form_copy['newAddress']['country'] = 'JPN'
        claim.form = form_copy.to_json

        claim
      end

      it 'updates veteran address zipCode to internationalPostalCode' do
        claim_service = VRE::Ch31Form.new(user:, claim: foreign_new_address_claim)
        response_double = double('response')

        allow(response_double).to receive(:body).and_return(
          { 'error_occurred' => false, 'application_intake' => '12345' }
        )

        expect(claim_service).to receive(:send_to_vre).with(
          payload: a_string_including('"internationalPostalCode":"93420"')
        ) { response_double }

        claim_service.submit
      end

      it 'updates veteran address stateCode to province' do
        claim_service = VRE::Ch31Form.new(user:, claim: foreign_new_address_claim)
        response_double = double('response')

        allow(response_double).to receive(:body).and_return(
          { 'error_occurred' => false, 'application_intake' => '12345' }
        )

        expect(claim_service).to receive(:send_to_vre).with(
          payload: a_string_including('"province":"CA"')
        ) { response_double }

        claim_service.submit
      end
    end
  end
end
