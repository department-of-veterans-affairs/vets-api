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
      let(:fes_data) do
        ClaimsApi::V1::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      context 'request structure' do
        it 'wraps data in proper FES request structure' do
          expect(fes_data).to have_key(:data)
          expect(fes_data[:data]).to have_key(:serviceTransactionId)
          expect(fes_data[:data]).to have_key(:veteranParticipantId)
          expect(fes_data[:data]).to have_key(:claimantParticipantId)
          expect(fes_data[:data]).to have_key(:form526)
        end

        it 'casts the participant IDs as integers' do
          expect(fes_data[:data][:veteranParticipantId]).to eq(600_061_742)
          expect(fes_data[:data][:claimantParticipantId]).to eq(600_061_742)
        end

        it 'finds the dependent participant_id as expected' do
          auth_headers['dependent'] = {}
          auth_headers['dependent']['participant_id'] = '8675309'

          expect(fes_data[:data][:claimantParticipantId]).to eq(8_675_309)
        end
      end

      context 'section 5 disabilities' do
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

          disability_object = fes_data[:data][:form526][:disabilities]

          expect(disability_object).not_to be_nil
          expect(disability_object[0][:name]).to eq('PTSD (post traumatic stress disorder)')
          expect(disability_object[0][:classificationCode]).to eq('123456')
          expect(disability_object[0][:ratedDisabilityId]).to eq('1100583')
          expect(disability_object[0][:diagnosticCode]).to eq(9999)
          expect(disability_object[0][:disabilityActionType]).to eq('NEW')
          expect(disability_object[0][:specialIssues]).to eq(['Fully Developed Claim', 'PTSD/2'])
          expect(disability_object[0][:approximateBeginDate]).to eq({ year: '2018', month: '02', day: '22' })
        end

        it 'maps secondary disabilities if included' do
          form_data['data']['attributes']['disabilities'][0]['secondaryDisabilities'] = secondary_disability

          disability_object = fes_data[:data][:form526][:disabilities]

          expect(disability_object[1][:name]).to eq('Left Hip Pain')
          expect(disability_object[1]).not_to have_key(:classificationCode)
          expect(disability_object[1]).not_to have_key(:ratedDisabilityId)
          expect(disability_object[1]).not_to have_key(:diagnosticCode)
          expect(disability_object[1][:disabilityActionType]).to eq('NEW')
          expect(disability_object[1]).not_to have_key(:specialIssues)
          expect(disability_object[1][:approximateBeginDate]).to eq({ year: '2018', month: '05' })
          expect(disability_object[2][:name]).to eq('Left Elbow Pain')
          expect(disability_object[2][:disabilityActionType]).to eq('NEW')
          expect(disability_object[2][:approximateBeginDate]).to eq({ year: '2019' })
        end

        it 'does not map the ignored fields' do
          form_data['data']['attributes']['disabilities'][0]['serviceRelevance'] = 'Hurt while working.'

          disability_object = fes_data[:data][:form526][:disabilities]

          expect(disability_object[0]).not_to have_key(:serviceRelevance)
          expect(disability_object[0]).not_to have_key(:secondaryDisabilities)
        end

        it 'removes a missing optional attribute' do
          form_data['data']['attributes']['disabilities'][0]['ratedDisabilityId'] = ' '
          form_data['data']['attributes']['disabilities'][0]['diagnosticCode'] = nil
          form_data['data']['attributes']['disabilities'][0]['specialIssues'] = []

          disability_object = fes_data[:data][:form526][:disabilities]

          expect(disability_object[0]).not_to have_key(:classificationCode)
          expect(disability_object[0]).not_to have_key(:ratedDisabilityId)
          expect(disability_object[0]).not_to have_key(:diagnosticCode)
          expect(disability_object[0]).not_to have_key(:specialIssues)
        end

        it "removes disabilities with disabilityActionType 'none'" do
          form_data['data']['attributes']['disabilities'][0]['disabilityActionType'] = 'NONE'

          disability_object = fes_data[:data][:form526][:disabilities]
          # 2 disabilities sent
          expect(disability_object.count).to eq(1)
        end
      end

      context 'section 6 service information' do
        let(:confinements_data) do
          [
            {
              'confinementBeginDate' => '2018-06-04',
              'confinementEndDate' => '2018-07-04'
            },
            {
              'confinementBeginDate' => '2020-06',
              'confinementEndDate' => '2020-07'
            }
          ]
        end
        let(:title_10_activation) do
          {
            'anticipatedSeparationDate' => '2025-12-01',
            'title10ActivationDate' => '2023-01-01'
          }
        end

        it 'maps the attributes' do
          form_data['data']['attributes']['serviceInformation']['servicePeriods'][0]['separationLocationCode'] = '98282'

          service_info_object = fes_data[:data][:form526][:serviceInformation]
          first_service_period_info = service_info_object[:servicePeriods][0]

          expect(first_service_period_info[:serviceBranch]).to eq('Air Force')
          expect(first_service_period_info[:activeDutyBeginDate]).to eq('1980-02-05')
          expect(first_service_period_info[:activeDutyEndDate]).to eq('1990-01-02')
          expect(first_service_period_info[:separationLocationCode]).to eq('98282')
          expect(service_info_object).not_to have_key(:confinements)
        end

        it 'removes nil values from the servicePeriods' do
          form_service_info_data = form_data['data']['attributes']['serviceInformation']
          form_service_info_data['servicePeriods'][0]['separationLocationCode'] = nil

          service_info_object = fes_data[:data][:form526][:serviceInformation]

          expect(service_info_object[:servicePeriods][0]).not_to have_key(:separationLocationCode)
        end

        it 'maps the confinements attribute correctly' do
          form_data['data']['attributes']['serviceInformation']['confinements'] =
            confinements_data

          first_confinement = fes_data[:data][:form526][:serviceInformation][:confinements][0]
          second_confinement = fes_data[:data][:form526][:serviceInformation][:confinements][1]

          expect(first_confinement[:confinementBeginDate]).to eq('2018-06-04')
          expect(first_confinement[:confinementEndDate]).to eq('2018-07-04')
          expect(second_confinement[:confinementBeginDate]).to eq('2020-06')
          expect(second_confinement[:confinementEndDate]).to eq('2020-07')
        end

        it 'maps the reserves attributes' do
          reserves_info_data = fes_data[:data][:form526][:serviceInformation][:reservesNationalGuardService]

          expect(reserves_info_data[:obligationTermOfServiceFromDate]).to eq('2000-01-01')
          expect(reserves_info_data[:obligationTermOfServiceToDate]).to eq('2000-01-02')
          expect(reserves_info_data).not_to have_key(:title10Activation)
        end

        it 'maps the optional title 10 attributes' do
          form_service_info_data = form_data['data']['attributes']['serviceInformation']
          form_service_info_data['reservesNationalGuardService']['title10Activation'] = title_10_activation

          reserves_info_data = fes_data[:data][:form526][:serviceInformation][:reservesNationalGuardService]

          expect(reserves_info_data).to have_key(:title10Activation)
          expect(reserves_info_data[:title10Activation][:anticipatedSeparationDate]).to eq('2025-12-01')
          expect(reserves_info_data[:title10Activation][:title10ActivationDate]).to eq('2023-01-01')
        end
      end
    end
  end
end
