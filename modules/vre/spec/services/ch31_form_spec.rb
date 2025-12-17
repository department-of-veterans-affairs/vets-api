# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31Form do
  let(:claim) { create(:veteran_readiness_employment_claim) }
  let(:claim_with_minimal_form) { create(:veteran_readiness_employment_claim_minimal) }
  let(:user) { create(:evss_user, :loa3) }
  let(:service) { VRE::Ch31Form.new(user:, claim:) }
  let(:service_with_minimal_form) { VRE::Ch31Form.new(user:, claim: claim_with_minimal_form) }
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

    context 'with a successful form submission' do
      before do
        allow(service).to receive(:send_to_res).and_return(success_message)
      end

      it 'adds a new address if the user is moving within 30 days' do
        expect(service).to receive(:new_address) { new_address_hash }
        service.submit
      end
    end

    context 'with vre_send_icn_to_res feature toggle enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:vre_send_icn_to_res).and_return(true)
      end

      context 'when all fields are supplied' do
        it 'forms params with matching supplied data' do
          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: true,
            mainPhone: '2222222222',
            cellNumber: '3333333333',
            internationalNumber: '+4444444444',
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim.created_at.iso8601,
            veteranAddress: {
              country: 'USA',
              street: '12 usa street',
              city: 'New York',
              state: 'NY',
              postalCode: '10001'
            },
            veteranInformation: {
              fullName: {
                first: 'First',
                middle: 'Middle',
                last: 'Last',
                suffix: 'III'
              },
              dob: '1980-01-01',
              regionalOffice: nil,
              icn: user.icn
            },
            newAddress: {
              country: 'USA',
              street: '13 usa street',
              city: 'New York',
              state: 'NY',
              postalCode: '10001'
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service.submit
        end
      end

      context 'when only required fields are supplied' do
        it 'forms params with null data attributes' do
          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: false,
            mainPhone: nil,
            cellNumber: nil,
            internationalNumber: nil,
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim_with_minimal_form.created_at.iso8601,
            veteranAddress: nil,
            veteranInformation: {
              fullName: {
                first: 'First',
                last: 'Last'
              },
              dob: '1980-01-01',
              regionalOffice: nil,
              icn: user.icn
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service_with_minimal_form.submit
        end

        it 'sends ICN as null if not present' do
          user.identity.icn = ''

          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: false,
            mainPhone: nil,
            cellNumber: nil,
            internationalNumber: nil,
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim_with_minimal_form.created_at.iso8601,
            veteranAddress: nil,
            veteranInformation: {
              fullName: {
                first: 'First',
                last: 'Last'
              },
              dob: '1980-01-01',
              regionalOffice: nil,
              icn: nil
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service_with_minimal_form.submit
        end
      end
    end

    context 'with vre_send_icn_to_res feature toggle disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:vre_send_icn_to_res).and_return(false)
      end

      context 'when all fields are supplied' do
        it 'forms params with matching supplied data' do
          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: true,
            mainPhone: '2222222222',
            cellNumber: '3333333333',
            internationalNumber: '+4444444444',
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim.created_at.iso8601,
            veteranAddress: {
              country: 'USA',
              street: '12 usa street',
              city: 'New York',
              state: 'NY',
              postalCode: '10001'
            },
            veteranInformation: {
              fullName: {
                first: 'First',
                middle: 'Middle',
                last: 'Last',
                suffix: 'III'
              },
              dob: '1980-01-01',
              regionalOffice: nil
            },
            newAddress: {
              country: 'USA',
              street: '13 usa street',
              city: 'New York',
              state: 'NY',
              postalCode: '10001'
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service.submit
        end
      end

      context 'when only required fields are supplied' do
        it 'forms params with null data attributes' do
          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: false,
            mainPhone: nil,
            cellNumber: nil,
            internationalNumber: nil,
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim_with_minimal_form.created_at.iso8601,
            veteranAddress: nil,
            veteranInformation: {
              fullName: {
                first: 'First',
                last: 'Last'
              },
              dob: '1980-01-01',
              regionalOffice: nil
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service_with_minimal_form.submit
        end

        it 'does not send ICN as null if not present' do
          user.identity.icn = ''

          payload = {
            useEva: nil,
            receiveElectronicCommunication: nil,
            useTelecounseling: nil,
            appointmentTimePreferences: nil,
            privacyStatementAcknowledged: true,
            yearsOfEducation: '10',
            isMoving: false,
            mainPhone: nil,
            cellNumber: nil,
            internationalNumber: nil,
            email: 'email@test.com',
            documentId: nil,
            receivedDate: claim_with_minimal_form.created_at.iso8601,
            veteranAddress: nil,
            veteranInformation: {
              fullName: {
                first: 'First',
                last: 'Last'
              },
              dob: '1980-01-01',
              regionalOffice: nil
            }
          }.to_json
          expect_any_instance_of(VRE::Service).to receive(:send_to_res).with(payload:).and_return(success_message)

          service_with_minimal_form.submit
        end
      end
    end

    context 'with an unsuccessful submission' do
      it 'does not successfully send to RES' do
        allow(service).to receive(:send_to_res).and_return(OpenStruct.new(body: { 'error' => 'Error' }))
        expect { service.submit }.to raise_error(VRE::Ch31Form::Ch31Error)
      end

      it 'handles nil claim' do
        nil_claim_service = VRE::Ch31Form.new(user:, claim: nil)
        expect { nil_claim_service.submit }.to raise_error(VRE::Ch31Form::Ch31NilClaimError)
      end
    end
  end
end
