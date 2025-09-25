# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_fes_mapper'

describe ClaimsApi::V1::DisabilityCompensationFesMapper do
  describe '526 claim maps to FES format' do
    context 'with v1 form data' do
      let(:form_data) do
        JSON.parse(
          Rails.root.join(
            'modules',
            'claims_api',
            'spec',
            'fixtures',
            'form_526_json_api.json'
          ).read
        )
      end

      let(:auth_headers) do
        {
          'va_eauth_pid' => '600061742',
          'va_eauth_service_transaction_id' => '00000000-0000-0000-0000-000000000000'
        }
      end

      let(:auto_claim) do
        create(:auto_established_claim,
               form_data: form_data['data']['attributes'],
               auth_headers:)
      end

      let(:fes_data) { described_class.new(auto_claim).map_claim }

      context 'request structure' do
        it 'wraps data in proper FES request structure' do
          expect(fes_data).to have_key(:data)
          expect(fes_data[:data]).to have_key(:serviceTransactionId)
          expect(fes_data[:data]).to have_key(:veteranParticipantId)
          expect(fes_data[:data]).to have_key(:claimantParticipantId)
          expect(fes_data[:data]).to have_key(:form526)
        end

        it 'finds the dependent participant_id as expected' do
          auth_headers['dependent'] = {}
          auth_headers['dependent']['participant_id'] = '8675309'

          expect(fes_data[:data][:claimantParticipantId]).to eq('8675309')
        end
      end

      describe 'veteran information' do
        let(:veteran) { fes_data[:data][:form526][:veteran] }

        describe 'current mailing address' do
          context 'when address is domestic' do
            it 'maps as DOMESTIC with full fields' do
              addr = veteran[:currentMailingAddress]
              expect(addr[:addressLine1]).to eq('1234 Couch Street')
              expect(addr[:addressLine2]).to eq('Apt. 22')
              expect(addr[:addressLine3]).to be_nil
              expect(addr[:city]).to eq('Portland')
              expect(addr[:state]).to eq('OR')
              expect(addr[:country]).to eq('USA')
              expect(addr[:zipFirstFive]).to eq('12345')
              expect(addr[:zipLastFour]).to eq('6789')
              expect(addr[:addressType]).to eq('DOMESTIC')
            end
          end

          context 'when address is military (APO/FPO/DPO)' do
            let(:auto_claim) do
              attrs = form_data['data']['attributes'].deep_dup
              attrs['veteranIdentification'] = {
                'currentVaEmployee' => false,
                'mailingAddress' => {
                  'numberAndStreet' => 'CMR 468 Box 1181',
                  'city' => 'APO',
                  'state' => 'AE',
                  'country' => 'USA',
                  'zipFirstFive' => '09277'
                }
              }
              create(:auto_established_claim, form_data: attrs, auth_headers:)
            end

            it 'maps as MILITARY and omits city/state' do
              addr = veteran[:currentMailingAddress]
              expect(addr[:addressLine1]).to eq('CMR 468 Box 1181')
              expect(addr[:militaryPostOfficeTypeCode]).to eq('APO')
              expect(addr[:militaryStateCode]).to eq('AE')
              expect(addr[:addressType]).to eq('MILITARY')
              expect(addr).not_to have_key(:city)
              expect(addr).not_to have_key(:state)
            end
          end

          context 'when address is international' do
            let(:auto_claim) do
              attrs = form_data['data']['attributes'].deep_dup
              attrs['veteranIdentification'] = {
                'currentVaEmployee' => false,
                'mailingAddress' => {
                  'numberAndStreet' => '123 Main St',
                  'city' => 'London',
                  'country' => 'GBR',
                  'internationalPostalCode' => 'SW1A 1AA'
                }
              }
              create(:auto_established_claim, form_data: attrs, auth_headers:)
            end

            it 'maps as INTERNATIONAL with postal code' do
              addr = veteran[:currentMailingAddress]
              expect(addr[:addressLine1]).to eq('123 Main St')
              expect(addr[:internationalPostalCode]).to eq('SW1A 1AA')
              expect(addr[:addressType]).to eq('INTERNATIONAL')
              expect(addr[:country]).to eq('GBR')
            end
          end
        end

        describe 'change of address' do
          context 'when present' do
            let(:auto_claim) do
              attrs = form_data['data']['attributes'].deep_dup
              attrs['changeOfAddress'] = {
                'typeOfAddressChange' => 'TEMPORARY',
                'numberAndStreet' => '10 Peach St',
                'apartmentOrUnitNumber' => 'Unit 4',
                'city' => 'Schenectady',
                'state' => 'NY',
                'country' => 'USA',
                'zipFirstFive' => '12345',
                'beginningDate' => '2023-06-04',
                'endingDate' => '2023-12-04'
              }
              create(:auto_established_claim, form_data: attrs, auth_headers:)
            end

            it 'maps fields and dates correctly' do
              change = veteran[:changeOfAddress]
              expect(change[:addressChangeType]).to eq('TEMPORARY')
              expect(change[:addressLine1]).to eq('10 Peach St Unit 4')
              expect(change[:beginningDate]).to eq('2023-06-04')
              expect(change[:endingDate]).to eq('2023-12-04')
              expect(change[:addressType]).to eq('DOMESTIC')
            end
          end
        end
      end

      context 'section 5 disabilities' do
        let(:fes_data) { described_class.new(auto_claim).map_claim }
        let(:disability_object) { fes_data[:data][:form526][:disabilities] }

        let(:secondary_disability) do
          [
            {
              'name' => 'Left Hip Pain',
              'disabilityActionType' => 'SECONDARY',
              'serviceRelevance' => 'Caused by a service-connected disability',
              'approximateBeginDate' => '2018-05'
            },
            {
              'name' => 'Left Elbow Pain',
              'disabilityActionType' => 'SECONDARY',
              'serviceRelevance' => 'Caused by a service-connected disability',
              'approximateBeginDate' => '2019'
            }
          ]
        end

        it 'maps the FES attributes' do
          form_data['data']['attributes']['disabilities'][0]['classificationCode'] = '123456'
          form_data['data']['attributes']['disabilities'][0]['approximateBeginDate'] = '2018-02-22'
          expect(disability_object).not_to be_nil
          expect(disability_object[0][:name]).to eq('PTSD (post traumatic stress disorder)')
          expect(disability_object[0][:classificationCode]).to eq('123456')
          expect(disability_object[0][:ratedDisabilityId]).to eq('1100583')
          expect(disability_object[0][:diagnosticCode]).to eq(9999)
          expect(disability_object[0][:disabilityActionType]).to eq('NEW')
          expect(disability_object[0][:specialIssues]).to eq(['Fully Developed Claim', 'PTSD/2'])
          expect(disability_object[0][:approximateBeginDate]).to eq({ year: 2018, month: 0o2, day: 22 })
        end

        it 'maps secondary disabilities if included' do
          form_data['data']['attributes']['disabilities'][0]['secondaryDisabilities'] = secondary_disability
          expect(disability_object[1][:name]).to eq('Left Hip Pain')
          expect(disability_object[1]).not_to have_key(:classificationCode)
          expect(disability_object[1]).not_to have_key(:ratedDisabilityId)
          expect(disability_object[1]).not_to have_key(:diagnosticCode)
          expect(disability_object[1][:disabilityActionType]).to eq('NEW')
          expect(disability_object[1]).not_to have_key(:specialIssues)
          expect(disability_object[1][:approximateBeginDate]).to eq({ year: 2018, month: 0o5 })
          expect(disability_object[2][:name]).to eq('Left Elbow Pain')
          expect(disability_object[2][:disabilityActionType]).to eq('NEW')
          expect(disability_object[2][:approximateBeginDate]).to eq({ year: 2019 })
        end

        it 'does not map the ignored fields' do
          form_data['data']['attributes']['disabilities'][0]['serviceRelevance'] = 'Hurt while working.'
          expect(disability_object[0]).not_to have_key(:serviceRelevance)
          expect(disability_object[0]).not_to have_key(:secondaryDisabilities)
        end

        it 'removes a missing optional attribute' do
          form_data['data']['attributes']['disabilities'][0]['ratedDisabilityId'] = ' '
          form_data['data']['attributes']['disabilities'][0]['diagnosticCode'] = nil
          form_data['data']['attributes']['disabilities'][0]['specialIssues'] = []
          expect(disability_object[0]).not_to have_key(:classificationCode)
          expect(disability_object[0]).not_to have_key(:ratedDisabilityId)
          expect(disability_object[0]).not_to have_key(:diagnosticCode)
          expect(disability_object[0]).not_to have_key(:specialIssues)
        end
      end
    end
  end
end
