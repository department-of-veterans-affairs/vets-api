# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_fes_mapper'

describe ClaimsApi::V2::DisabilityCompensationFesMapper do
  describe '526 claim maps to FES format' do
    context 'with v2 form data' do
      let(:form_data) do
        JSON.parse(
          Rails.root.join(
            'modules',
            'claims_api',
            'spec',
            'fixtures',
            'v2',
            'veterans',
            'disability_compensation',
            'form_526_json_api.json'
          ).read
        )
      end
      let(:auto_claim) do
        create(:auto_established_claim,
               form_data: form_data['data']['attributes'],
               auth_headers: { 'va_eauth_pid' => '600061742',
                               'va_eauth_service_transaction_id' => '00000000-0000-0000-0000-000000000000' })
      end
      let(:fes_data) do
        ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      def map_claim_with_modified_data(base_form_data, auth_headers = { 'va_eauth_pid' => '600061742' })
        auto_claim = create(:auto_established_claim,
                            form_data: base_form_data['data']['attributes'],
                            auth_headers:)
        ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      context 'request structure' do
        it 'wraps data in proper FES request structure' do
          expect(fes_data).to have_key(:data)
          expect(fes_data[:data]).to have_key(:serviceTransactionId)
          expect(fes_data[:data]).to have_key(:claimantParticipantId)
          expect(fes_data[:data]).to have_key(:veteranParticipantId)
          expect(fes_data[:data]).to have_key(:form526)
        end

        it 'includes participant IDs' do
          expect(fes_data[:data][:claimantParticipantId]).to eq('600061742')
          expect(fes_data[:data][:veteranParticipantId]).to eq('600061742')
        end

        it 'maps the transaction ID provided in headers to the serviceTransactionId' do
          expect(fes_data[:data][:serviceTransactionId]).to match(
            auto_claim.auth_headers['va_eauth_service_transaction_id']
          )
        end

        context 'when auto claim has no transaction ID in headers' do
          let(:auto_claim) do
            create(:auto_established_claim,
                   form_data: form_data['data']['attributes'],
                   auth_headers: { 'va_eauth_pid' => '600061742' })
          end

          it 'sets serviceTransactionId to nil' do
            expect(fes_data[:data][:serviceTransactionId]).to be_nil
          end
        end
      end

      context 'veteran information' do
        let(:veteran_data) { fes_data[:data][:form526][:veteran] }

        context 'mailing address' do
          it 'maps domestic address correctly' do
            address = veteran_data[:currentMailingAddress]
            expect(address[:addressLine1]).to eq('1234 Couch Street')
            expect(address[:addressLine2]).to eq('Unit 4')
            expect(address[:addressLine3]).to eq('Room 1')
            expect(address[:city]).to eq('Schenectady')
            expect(address[:state]).to eq('NY')
            expect(address[:country]).to eq('USA')
            expect(address[:zipFirstFive]).to eq('12345')
            expect(address[:zipLastFour]).to eq('1234')
            expect(address[:addressType]).to eq('DOMESTIC')
          end

          context 'military address' do
            let(:veteran_identification) do
              {
                currentVaEmployee: false,
                mailingAddress: {
                  addressLine1: 'CMR 468',
                  addressLine3: 'Box 1181',
                  city: 'APO',
                  state: 'AE',
                  country: 'USA',
                  zipFirstFive: '09277'
                }
              }
            end

            it 'maps military address correctly' do
              form_data['data']['attributes']['veteranIdentification'] = veteran_identification
              fes_data = map_claim_with_modified_data(form_data)
              address = fes_data[:data][:form526][:veteran][:currentMailingAddress]

              expect(address[:addressLine1]).to eq('CMR 468')
              expect(address[:addressLine3]).to eq('Box 1181')
              expect(address[:militaryPostOfficeTypeCode]).to eq('APO')
              expect(address[:militaryStateCode]).to eq('AE')
              expect(address[:addressType]).to eq('MILITARY')
              expect(address).not_to have_key(:city)
              expect(address).not_to have_key(:state)
            end
          end

          context 'international address' do
            let(:veteran_identification) do
              {
                currentVaEmployee: false,
                mailingAddress: {
                  addressLine1: '123 Main St',
                  city: 'London',
                  country: 'GBR',
                  internationalPostalCode: 'SW1A 1AA'
                }
              }
            end

            it 'maps international address correctly' do
              form_data['data']['attributes']['veteranIdentification'] = veteran_identification
              fes_data = map_claim_with_modified_data(form_data)
              address = fes_data[:data][:form526][:veteran][:currentMailingAddress]

              expect(address[:addressLine1]).to eq('123 Main St')
              expect(address[:internationalPostalCode]).to eq('SW1A 1AA')
              expect(address[:addressType]).to eq('INTERNATIONAL')
              expect(address[:country]).to eq('GBR')
              expect(address[:city]).to eq('London')
            end
          end
        end

        context 'change of address' do
          it 'maps change of address when present' do
            form_data['data']['attributes']['changeOfAddress'] = {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '10 Peach St',
              'addressLine2' => 'Unit 4',
              'city' => 'Schenectady',
              'state' => 'NY',
              'country' => 'USA',
              'zipFirstFive' => '12345',
              'beginningDate' => '2023-06-04',
              'endingDate' => '2023-12-04'
            }

            fes_data = map_claim_with_modified_data(form_data)
            change = fes_data[:data][:form526][:veteran][:changeOfAddress]

            expect(change[:addressChangeType]).to eq('TEMPORARY')
            expect(change[:addressLine1]).to eq('10 Peach St')
            expect(change[:addressLine2]).to eq('Unit 4')
            expect(change[:beginningDate]).to eq('2023-06-04')
            expect(change[:endingDate]).to eq('2023-12-04')
            expect(change[:addressType]).to eq('DOMESTIC')
            expect(change[:city]).to eq('Schenectady')
          end
        end

        context 'change of address for international address' do
          it 'maps change of address when address is international' do
            form_data['data']['attributes']['changeOfAddress'] = {
              'typeOfAddressChange' => 'TEMPORARY',
              'addressLine1' => '10 Peach St',
              'city' => 'London',
              'country' => 'GBR',
              'internationalPostalCode' => 'SW1A 1AA',
              'beginningDate' => '2023-06-04',
              'endingDate' => '2023-12-04'
            }

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })
            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
            change = fes_data[:data][:form526][:veteran][:changeOfAddress]

            expect(change[:addressLine1]).to eq('10 Peach St')
            expect(change[:internationalPostalCode]).to eq('SW1A 1AA')
            expect(change[:beginningDate]).to eq('2023-06-04')
            expect(change[:endingDate]).to eq('2023-12-04')
            expect(change[:addressType]).to eq('INTERNATIONAL')
            expect(change[:country]).to eq('GBR')
            expect(change[:city]).to eq('London')
          end
        end
      end

      context 'service information' do
        let(:service_info) { fes_data[:data][:form526][:serviceInformation] }

        it 'maps service periods correctly' do
          periods = service_info[:servicePeriods]

          expect(periods).to be_an(Array)
          expect(periods.first[:serviceBranch]).to eq('Public Health Service')
          expect(periods.first[:activeDutyBeginDate]).to eq('2008-11-14')
          expect(periods.first[:activeDutyEndDate]).to eq('2023-10-30')
        end

        it 'maps reserves national guard service correctly' do
          reserves = service_info[:reservesNationalGuardService]
          title10 = reserves[:title10Activation]

          expect(reserves[:obligationTermOfServiceFromDate]).to eq('2019-06-04')
          expect(reserves[:obligationTermOfServiceToDate]).to eq('2020-06-04')
          expect(title10[:title10ActivationDate]).to eq('2023-10-01')
          expect(title10[:anticipatedSeparationDate]).to eq('2025-10-31')
        end

        context 'federal activation' do
          it 'maps correctly when only anticipatedSeparationDate is present' do
            form_service_info = form_data['data']['attributes']['serviceInformation']
            form_service_info['federalActivation']['activationDate'] = nil
            title10 = service_info[:reservesNationalGuardService][:title10Activation]

            expect(title10).not_to have_key(:title10ActivationDate)
          end

          it 'maps correctly when only activationDate is present' do
            form_service_info = form_data['data']['attributes']['serviceInformation']
            form_service_info['federalActivation']['anticipatedSeparationDate'] = nil
            title10 = service_info[:reservesNationalGuardService][:title10Activation]

            expect(title10).not_to have_key(:anticipatedSeparationDate)
          end

          it 'maps correctly when both fields are sent in as null' do
            form_service_info = form_data['data']['attributes']['serviceInformation']
            form_service_info['federalActivation']['anticipatedSeparationDate'] = nil
            form_service_info['federalActivation']['activationDate'] = nil
            reserves = service_info[:reservesNationalGuardService]

            expect(reserves).not_to have_key(:title10Activation)
          end
        end

        context 'confinements' do
          it 'maps confinements when present' do
            confinements = service_info[:confinements]

            expect(confinements).to be_an(Array)
            expect(confinements.first[:confinementBeginDate]).to eq('2018-06-04')
            expect(confinements.first[:confinementEndDate]).to eq('2018-07-04')
          end

          it 'handles null confinements sent in' do
            form_data['data']['attributes']['serviceInformation']['confinements'] = nil

            expect(service_info).not_to have_key(:confinements)
          end
        end

        context 'separationLocationCode' do
          let(:service_periods) do
            [
              {
                'serviceBranch' => 'Public Health Service',
                'serviceComponent' => 'Active',
                'activeDutyBeginDate' => '2021-11-14',
                'activeDutyEndDate' => '2023-10-30',
                'separationLocationCode' => '98765'
              }, {
                'serviceBranch' => 'Army',
                'activeDutyBeginDate' => '2018-11-14',
                'activeDutyEndDate' => '2020-10-30'
              }, {
                'serviceBranch' => 'Navy',
                'activeDutyBeginDate' => '2008-11-14',
                'activeDutyEndDate' => '2023-10-30',
                'separationLocationCode' => '12345'
              }
            ]
          end

          it 'maps separation location correctly when present' do
            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })

            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            expect(fes_data[:data][:form526][:serviceInformation][:separationLocationCode]).to eq('98282')
          end

          it 'maps separation location correctly when there are multiple present' do
            form_data['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods
            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })

            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            expect(fes_data[:data][:form526][:serviceInformation][:separationLocationCode]).to eq('98765')
          end

          it 'handles separation code when it is not present in most recent service period' do
            modified_periods = service_periods.deep_dup
            modified_periods[0].delete('separationLocationCode')
            form_data['data']['attributes']['serviceInformation']['servicePeriods'] = modified_periods
            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })

            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            expect(fes_data[:data][:form526][:serviceInformation]).not_to have_key(:separationLocationCode)
          end
        end
      end

      context 'disabilities' do
        let(:disabilities) { fes_data[:data][:form526][:disabilities] }

        it 'maps basic disability fields' do
          disability = disabilities.first
          expect(disability[:name]).to eq('Traumatic Brain Injury')
          expect(disability[:disabilityActionType]).to eq('NEW')
          expect(disability[:classificationCode]).to eq('9014')
          expect(disability[:ratedDisabilityId]).to eq('ABCDEFGHIJKLMNOPQRSTUVWX')
          expect(disability[:diagnosticCode]).to eq(9020)
        end

        it 'maps approximate date correctly' do
          form_data['data']['attributes']['disabilities'][0]['approximateDate'] = {
            'year' => 2020,
            'month' => 6,
            'day' => 15
          }
          fes_data = map_claim_with_modified_data(form_data)
          date = fes_data[:data][:form526][:disabilities].first[:approximateBeginDate]

          expect(date[:year]).to eq(2020)
          expect(date[:month]).to eq(6)
          expect(date[:day]).to eq(15)
        end

        it "removes disabilities with a disabilityActionType of 'none'" do
          form_data['data']['attributes']['disabilities'][0]['disabilityActionType'] = 'NONE'

          fes_data = map_claim_with_modified_data(form_data)
          # with the included secondary disability there are 4 disabilities that are mapped
          expect(fes_data[:data][:form526][:disabilities].count).to eq(3)
        end

        context 'when secondary disabilities are present' do
          it 'extracts and flattens secondary disabilities' do
            form_data['data']['attributes']['disabilities'][0]['secondaryDisabilities'] = [
              {
                'name' => 'Secondary Condition',
                'disabilityActionType' => 'SECONDARY',
                'diagnosticCode' => 5002,
                'isRelatedToToxicExposure' => false
              }
            ]
            fes_data = map_claim_with_modified_data(form_data)
            disabilities = fes_data[:data][:form526][:disabilities]
            secondary = disabilities.find { |d| d[:name] == 'Secondary Condition' }

            expect(disabilities.count).to eq(4)
            expect(secondary).to be_present
            expect(secondary[:disabilityActionType]).to eq('NEW')
            expect(secondary[:diagnosticCode]).to eq(5002)
          end
        end

        context 'PACT special issue' do
          it 'adds PACT special issue for toxic exposure when action type is NEW' do
            expect(disabilities.first[:specialIssues]).to include('PACT')
          end

          it 'does not add PACT for INCREASE action type' do
            form_data['data']['attributes']['disabilities'][0]['disabilityActionType'] = 'INCREASE'
            form_data['data']['attributes']['disabilities'][0]['isRelatedToToxicExposure'] = true

            fes_data = map_claim_with_modified_data(form_data)
            disability = fes_data[:data][:form526][:disabilities].first

            expect(disability[:specialIssues]).to be_nil
          end

          it 'combines existing special issues with PACT' do
            form_data['data']['attributes']['disabilities'][0]['specialIssues'] = %w[POW EMP]
            form_data['data']['attributes']['disabilities'][0]['isRelatedToToxicExposure'] = true

            fes_data = map_claim_with_modified_data(form_data)
            special_issues = fes_data[:data][:form526][:disabilities].first[:specialIssues]

            expect(special_issues).to contain_exactly('POW', 'EMP', 'PACT')
          end

          it 'applies PACT special issue to secondary disabilities when appropriate' do
            form_data['data']['attributes']['disabilities'][0]['secondaryDisabilities'] = [
              {
                'name' => 'Secondary With PACT',
                'disabilityActionType' => 'SECONDARY',
                'isRelatedToToxicExposure' => true
              },
              {
                'name' => 'Secondary Without PACT',
                'disabilityActionType' => 'SECONDARY',
                'isRelatedToToxicExposure' => false
              }
            ]

            fes_data = map_claim_with_modified_data(form_data)
            disabilities = fes_data[:data][:form526][:disabilities]
            with_pact = disabilities.find { |d| d[:name] == 'Secondary With PACT' }
            without_pact = disabilities.find { |d| d[:name] == 'Secondary Without PACT' }

            expect(with_pact[:specialIssues]).to include('PACT')
            expect(without_pact[:specialIssues]).to be_nil
          end
        end
      end

      context 'special circumstances' do
        it 'maps special circumstances when present' do
          form_data['data']['attributes']['specialCircumstances'] = [
            {
              'code' => 'AA',
              'name' => 'Automobile Allowance',
              'needed' => true
            },
            {
              'code' => 'SAH',
              'name' => 'Specially Adapted Housing',
              'needed' => false
            }
          ]
          fes_data = map_claim_with_modified_data(form_data)
          circumstances = fes_data[:data][:form526][:specialCircumstances]

          expect(circumstances).to be_an(Array)
          expect(circumstances.first[:code]).to eq('AA')
          expect(circumstances.first[:description]).to eq('Automobile Allowance')
          expect(circumstances.first[:needed]).to be true
        end
      end

      context 'claim date' do
        it 'uses provided claim date' do
          form_data['data']['attributes']['claimDate'] = '2024-01-15'
          fes_data = map_claim_with_modified_data(form_data)

          expect(fes_data[:data][:form526][:claimDate]).to eq('2024-01-15')
        end

        it 'defaults to today when claim date not provided' do
          form_data['data']['attributes'].delete('claimDate')
          fes_data = map_claim_with_modified_data(form_data)

          expect(fes_data[:data][:form526][:claimDate]).to eq(Time.zone.today.to_s)
        end
      end
    end
  end
end
