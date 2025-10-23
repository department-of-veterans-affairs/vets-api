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
                  numberAndStreet: 'CMR 468 Box 1181',
                  city: 'APO',
                  state: 'AE',
                  country: 'USA',
                  zipFirstFive: '09277'
                }
              }
            end

            it 'maps military address correctly' do
              form_data['data']['attributes']['veteranIdentification'] = veteran_identification
              auto_claim = create(:auto_established_claim,
                                  form_data: form_data['data']['attributes'],
                                  auth_headers: { 'va_eauth_pid' => '600061742' })
              fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
              address = fes_data[:data][:form526][:veteran][:currentMailingAddress]

              expect(address[:addressLine1]).to eq('CMR 468 Box 1181')
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
                  numberAndStreet: '123 Main St',
                  city: 'London',
                  country: 'GBR',
                  internationalPostalCode: 'SW1A 1AA'
                }
              }
            end

            it 'maps international address correctly' do
              form_data['data']['attributes']['veteranIdentification'] = veteran_identification
              auto_claim = create(:auto_established_claim,
                                  form_data: form_data['data']['attributes'],
                                  auth_headers: { 'va_eauth_pid' => '600061742' })
              fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
              address = fes_data[:data][:form526][:veteran][:currentMailingAddress]

              expect(address[:addressLine1]).to eq('123 Main St')
              expect(address[:internationalPostalCode]).to eq('SW1A 1AA')
              expect(address[:addressType]).to eq('INTERNATIONAL')
              expect(address[:country]).to eq('GBR')
            end
          end
        end

        context 'change of address' do
          it 'maps change of address when present' do
            form_data['data']['attributes']['changeOfAddress'] = {
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

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })
            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
            change = fes_data[:data][:form526][:veteran][:changeOfAddress]

            expect(change[:addressChangeType]).to eq('TEMPORARY')
            expect(change[:addressLine1]).to eq('10 Peach St Unit 4')
            expect(change[:beginningDate]).to eq('2023-06-04')
            expect(change[:endingDate]).to eq('2023-12-04')
            expect(change[:addressType]).to eq('DOMESTIC')
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
          expect(reserves[:obligationTermOfServiceFromDate]).to eq('2019-06-04')
          expect(reserves[:obligationTermOfServiceToDate]).to eq('2020-06-04')

          title10 = reserves[:title10Activation]
          expect(title10[:title10ActivationDate]).to eq('2023-10-01')
          expect(title10[:anticipatedSeparationDate]).to eq('2025-10-31')
        end

        it 'maps confinements correctly' do
          confinements = service_info[:confinements]
          expect(confinements).to be_an(Array)
          expect(confinements.first[:confinementBeginDate]).to eq('2018-06-04')
          expect(confinements.first[:confinementEndDate]).to eq('2018-07-04')
        end

        it 'maps separation location code when present' do
          form_data['data']['attributes']['serviceInformation']['separationLocationCode'] = '98282'
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })
          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

          expect(fes_data[:data][:form526][:serviceInformation][:separationLocationCode]).to eq('98282')
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

          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })
          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

          date = fes_data[:data][:form526][:disabilities].first[:approximateBeginDate]
          expect(date[:year]).to eq(2020)
          expect(date[:month]).to eq(6)
          expect(date[:day]).to eq(15)
        end

        context 'when secondary disabilities are present' do
          it 'extracts and flattens secondary disabilities' do
            # Add secondary disabilities to the test data
            form_data['data']['attributes']['disabilities'][0]['secondaryDisabilities'] = [
              {
                'name' => 'Secondary Condition',
                'disabilityActionType' => 'SECONDARY',
                'diagnosticCode' => 5002,
                'isRelatedToToxicExposure' => false
              }
            ]

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })

            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            disabilities = fes_data[:data][:form526][:disabilities]
            # Three primary disabilities and newly elevated secondary disability
            expect(disabilities.count).to eq(4)

            # Check the secondary condition
            secondary = disabilities.find { |d| d[:name] == 'Secondary Condition' }
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

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })
            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            disability = fes_data[:data][:form526][:disabilities].first
            expect(disability[:specialIssues]).to be_nil
          end

          it 'combines existing special issues with PACT' do
            form_data['data']['attributes']['disabilities'][0]['specialIssues'] = %w[POW EMP]
            form_data['data']['attributes']['disabilities'][0]['isRelatedToToxicExposure'] = true

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })
            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

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

            auto_claim = create(:auto_established_claim,
                                form_data: form_data['data']['attributes'],
                                auth_headers: { 'va_eauth_pid' => '600061742' })
            fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

            disabilities = fes_data[:data][:form526][:disabilities]

            # Find the secondaries
            with_pact = disabilities.find { |d| d[:name] == 'Secondary With PACT' }
            without_pact = disabilities.find { |d| d[:name] == 'Secondary Without PACT' }

            # Verify special issues
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

          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })
          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

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

          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })
          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

          expect(fes_data[:data][:form526][:claimDate]).to eq('2024-01-15')
        end

        it 'defaults to today when claim date not provided' do
          form_data['data']['attributes'].delete('claimDate')

          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })
          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim

          expect(fes_data[:data][:form526][:claimDate]).to eq(Time.zone.today.to_s)
        end
      end

      context 'required field validation' do
        it 'raises error when veteran participant ID is missing' do
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: {})

          mapper = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim)
          expect { mapper.map_claim }.to raise_error(ArgumentError, /Missing veteranParticipantId/)
        end

        it 'raises error when participant ID falls back to ICN' do
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: {},
                              veteran_icn: '1234567890V123456')

          mapper = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim)
          expect { mapper.map_claim }.to raise_error(ArgumentError, /Missing veteranParticipantId/)
        end

        it 'raises error when service periods are missing' do
          form_data['data']['attributes']['serviceInformation'].delete('servicePeriods')
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })

          mapper = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim)
          expect { mapper.map_claim }.to raise_error(ArgumentError,
                                                     /Missing required serviceInformation.servicePeriods/)
        end

        it 'raises error when disabilities are missing' do
          form_data['data']['attributes'].delete('disabilities')
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })

          mapper = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim)
          expect { mapper.map_claim }.to raise_error(ArgumentError, /Missing required disabilities array/)
        end

        it 'raises error when veteran mailing address is missing' do
          form_data['data']['attributes']['veteranIdentification'].delete('mailingAddress')
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: { 'va_eauth_pid' => '600061742' })

          mapper = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim)
          expect { mapper.map_claim }.to raise_error(ArgumentError, /Missing required veteran mailing address/)
        end

        it 'accepts dependent participant ID for claimant' do
          auto_claim = create(:auto_established_claim,
                              form_data: form_data['data']['attributes'],
                              auth_headers: {
                                'va_eauth_pid' => '600061742',
                                'dependent' => { 'participant_id' => '600061743' }
                              })

          fes_data = ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
          expect(fes_data[:data][:claimantParticipantId]).to eq('600061743')
          expect(fes_data[:data][:veteranParticipantId]).to eq('600061742')
        end
      end
    end

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
      let(:auto_claim) do
        create(:auto_established_claim,
               form_data: form_data['data']['attributes'],
               auth_headers: { 'va_eauth_pid' => '600061742' })
      end
      let(:fes_data) do
        ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      it 'maps v1 veteran data to FES format' do
        expect(fes_data).to have_key(:data)
        expect(fes_data[:data]).to have_key(:form526)
        expect(fes_data[:data][:form526]).to have_key(:veteran)
      end

      it 'maps v1 address correctly' do
        address = fes_data[:data][:form526][:veteran][:currentMailingAddress]
        expect(address).to include(
          addressLine1: '1234 Couch Street',
          city: 'Portland',
          state: 'OR',
          country: 'USA',
          zipFirstFive: '12345',
          addressType: 'DOMESTIC'
        )
      end

      it 'handles v1 disabilities structure' do
        disabilities = fes_data[:data][:form526][:disabilities]
        expect(disabilities).to be_an(Array)
        expect(disabilities).not_to be_empty
      end

      it 'handles v1 service information' do
        service_info = fes_data[:data][:form526][:serviceInformation]
        expect(service_info).to be_present
        expect(service_info[:servicePeriods]).to be_an(Array)
      end
    end
  end
end
