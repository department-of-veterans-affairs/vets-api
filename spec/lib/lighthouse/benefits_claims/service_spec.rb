# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'
require 'evss/disability_compensation_form/form_submit_response'

RSpec.describe BenefitsClaims::Service do
  before(:all) do
    @service = BenefitsClaims::Service.new('123498767V234859')
  end

  describe 'making requests' do
    context 'valid requests' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
      end

      describe 'when requesting intent_to_file' do
        # TODO-BDEX: Down the line, revisit re-generating cassettes using some local test credentials
        # and actual interaction with LH
        it 'retrieves a intent to file from the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            response = @service.get_intent_to_file('compensation', '', '')
            expect(response['data']['id']).to eq('193685')
          end
        end

        it 'creates intent to file using the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
            response = @service.create_intent_to_file('compensation', '', '')
            expect(response['data']['attributes']['type']).to eq('compensation')
          end
        end

        it 'creates intent to file with the survivor type' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_survivor_200_response') do
            response = @service.create_intent_to_file('survivor', '011223344', '', '')
            expect(response['data']['attributes']['type']).to eq('survivor')
          end
        end
      end

      describe 'when requesting a list of benefits claims' do
        it 'retrieves a list of benefits claims from the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            response = @service.get_claims
            expect(response.dig('data', 0, 'id')).to eq('600383363')
          end
        end

        it 'filters out claims with certain statuses' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            response = @service.get_claims
            expect(response['data'].length).to eq(6)
          end
        end

        it 'filters out claims with certain base end product codes' do
          data = [{ 'id' => '600561746',
                    'type' => 'claim',
                    'attributes' =>
                     { 'baseEndProductCode' => '020',
                       'claimDate' => '2024-09-24',
                       'claimPhaseDates' => { 'phaseChangeDate' => '2024-11-20', 'phaseType' => 'COMPLETE' },
                       'claimType' => 'Compensation',
                       'claimTypeCode' => '020SUPP',
                       'closeDate' => '2024-11-20',
                       'decisionLetterSent' => true,
                       'developmentLetterSent' => false,
                       'documentsNeeded' => false,
                       'endProductCode' => '020',
                       'evidenceWaiverSubmitted5103' => false,
                       'lighthouseId' => '2615b33c-cfe8-4dbe-a331-c69f01863750',
                       'status' => 'OPEN' } },
                  { 'id' => '600561747',
                    'type' => 'claim',
                    'attributes' =>
                      { 'baseEndProductCode' => '960',
                        'claimDate' => '2024-09-24',
                        'claimPhaseDates' => { 'phaseChangeDate' => '2024-11-20', 'phaseType' => 'COMPLETE' },
                        'claimType' => 'Compensation',
                        'claimTypeCode' => '960ADMER',
                        'closeDate' => '2024-11-20',
                        'decisionLetterSent' => true,
                        'developmentLetterSent' => false,
                        'documentsNeeded' => false,
                        'endProductCode' => '961',
                        'evidenceWaiverSubmitted5103' => false,
                        'lighthouseId' => 'c72af21b-a82c-4ef2-a953-2a8b9afcb44a',
                        'status' => 'COMPLETE' } }]

          # #110154 - it should filter out the base end product code 960
          results = @service.send(:filter_by_ep_code, data)
          expect(results.length).to eq(1)
        end
      end

      describe 'when requesting one single benefit claim' do
        before { allow(Flipper).to receive(:enabled?).and_call_original }

        context 'when the PMR Pending override flipper is enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:cst_override_pmr_pending_tracked_items).and_return(true)
          end

          it 'has overridden PMR Pending tracked items to the NEEDED_FROM_OTHERS status and readable name' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              response = @service.get_claim('600383363')
              # In the cassette, the status is NEEDED_FROM_YOU
              expect(response.dig('data', 'attributes', 'trackedItems', 0, 'status')).to eq('NEEDED_FROM_OTHERS')
              expect(response.dig('data', 'attributes', 'trackedItems', 0,
                                  'displayName')).to eq('Private Medical Record')
            end
          end
        end

        context 'when the PMR Pending override flipper is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:cst_override_pmr_pending_tracked_items).and_return(false)
          end

          it 'has overridden PMR Pending tracked items to the NEEDED_FROM_OTHERS status and readable name' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              response = @service.get_claim('600383363')
              # In the cassette, the status is NEEDED_FROM_YOU
              expect(response.dig('data', 'attributes', 'trackedItems', 0, 'status')).to eq('NEEDED_FROM_YOU')
              expect(response.dig('data', 'attributes', 'trackedItems', 0, 'displayName')).to eq('PMR Pending')
            end
          end
        end
      end

      describe "when requesting a user's power of attorney" do
        context 'when the user has an active power of attorney' do
          it 'retrieves the power of attorney from the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
              response = @service.get_power_of_attorney
              expect(response['data']['type']).to eq('individual')
              expect(response['data']['attributes']['code']).to eq('067')
            end
          end
        end

        context 'when the user does not have an active power of attorney' do
          it 'retrieves the power of attorney from the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_empty_response') do
              response = @service.get_power_of_attorney
              expect(response['data']).to eq({})
            end
          end
        end
      end

      describe "when retrieving a user's power of attorney request status" do
        context 'when the user has submitted the form' do
          it 'retrieves the power of attorney request status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_status/200_response') do
              response = @service.get_2122_submission('29b7c214-4a61-425e-97f2-1a56de869524')
              expect(response.dig('data', 'type')).to eq('claimsApiPowerOfAttorneys')
              expect(response.dig('data', 'attributes', 'dateRequestAccepted')).to eq '2025-01-16'
              expect(response.dig(
                       'data', 'attributes', 'representative', 'representative', 'poaCode'
                     )).to eq '067'
            end
          end
        end

        context 'when the id does not exist' do
          it 'returns an 404 error' do
            VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_status/404_response') do
              expect do
                @service.get_2122_submission('491b878a-d977-40b8-8de9-7ba302307a48')
              end.to raise_error(Common::Exceptions::ResourceNotFound)
            end
          end
        end
      end

      describe 'when posting a form526' do
        it 'has formatted request body data correctly' do
          transaction_id = 'vagov'
          body = @service.send(:prepare_submission_body,
                               {
                                 'serviceInformation' => {
                                   'confinements' => []
                                 },
                                 'toxicExposure' => {
                                   'multipleExposures' => [],
                                   'herbicideHazardService' => {
                                     'serviceDates' => {
                                       'beginDate' => '1991-03-01',
                                       'endDate' => '1992-01-01'
                                     }
                                   }
                                 }
                               }, transaction_id)

          expect(body).to eq({
                               'data' => {
                                 'type' => 'form/526',
                                 'attributes' => {
                                   'serviceInformation' => {},
                                   'toxicExposure' => {
                                     'herbicideHazardService' => {
                                       'serviceDates' => {
                                         'beginDate' => '1991-03-01',
                                         'endDate' => '1992-01-01'
                                       }
                                     }
                                   }
                                 }
                               },
                               'meta' => {
                                 'transactionId' => 'vagov'
                               }
                             })
        end

        context 'when posting to the default /synchronous endpoint' do
          it 'when given a full request body, posts to the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_synchronous_response') do
              response = @service.submit526({ data: { attributes: {} } }, '', '', { body_only: true })
              response_json = JSON.parse(response)
              expect(response_json['data']['id']).to eq('46285849-9d82-4001-8572-2323d521eb8c')
              expect(response_json['data']['attributes']['claimId']).to eq('12345678')
            end
          end

          it 'when given only the form data in the request body, posts to the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_synchronous_response') do
              response = @service.submit526({}, '', '', { body_only: true })
              response_json = JSON.parse(response)
              expect(response_json['data']['id']).to eq('46285849-9d82-4001-8572-2323d521eb8c')
              expect(response_json['data']['attributes']['claimId']).to eq('12345678')
            end
          end

          it 'returns only the response body' do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_synchronous_response') do
              body = @service.submit526({ data: { attributes: {} } }, '', '', { body_only: true })
              response_json = JSON.parse(body)
              expect(response_json['data']['id']).to eq('46285849-9d82-4001-8572-2323d521eb8c')
              expect(response_json['data']['attributes']['claimId']).to eq('12345678')
            end
          end

          it 'returns the whole response' do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_synchronous_response') do
              raw_response = @service.submit526({}, '', '', { body_only: false })
              claim_id = JSON.parse(raw_response.body).dig('data', 'attributes', 'claimId').to_i
              raw_response_struct = OpenStruct.new({
                                                     body: { claim_id: },
                                                     status: raw_response.status
                                                   })
              response = EVSS::DisabilityCompensationForm::FormSubmitResponse
                         .new(raw_response_struct.status, raw_response_struct)

              expect(response.status).to eq(200)
              expect(response.claim_id).to eq(claim_id)
            end
          end
        end

        context 'when posting to the /validate endpoint' do
          it 'when given a full request body, posts to the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/validate526/200_synchronous_response') do
              raw_response = @service.validate526({ data: { attributes: {} } }, '', '', { body_only: true })
              response_json = JSON.parse(raw_response)
              expect(response_json.dig('data', 'attributes', 'status')).to eq('valid')
            end
          end

          it 'when given only the form data in the request body, posts to the Lighthouse API' do
            VCR.use_cassette('lighthouse/benefits_claims/validate526/200_synchronous_response') do
              raw_response = @service.validate526({}, '', '', { body_only: true })
              response_json = JSON.parse(raw_response)
              expect(response_json.dig('data', 'attributes', 'status')).to eq('valid')
            end
          end

          it 'returns only the response body' do
            VCR.use_cassette('lighthouse/benefits_claims/validate526/200_synchronous_response') do
              body = @service.validate526({ data: { attributes: {} } }, '', '', { body_only: true })
              response_json = JSON.parse(body)
              expect(response_json.dig('data', 'attributes', 'status')).to eq('valid')
            end
          end

          it 'returns the whole response' do
            VCR.use_cassette('lighthouse/benefits_claims/validate526/200_synchronous_response') do
              raw_response = @service.validate526({}, '', '', { body_only: false })
              response_json = JSON.parse(raw_response.body)
              expect(raw_response.status).to eq(200)
              expect(response_json.dig('data', 'attributes', 'status')).to eq('valid')
            end
          end
        end

        context 'when given the option to use generate pdf' do
          it 'calls the generate pdf endpoint' do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
              raw_response = @service.submit526({}, '', '', { generate_pdf: true })
              expect(raw_response.body).to eq('No example available')
            end
          end
        end
      end

      describe 'when submitting a 2122' do
        let(:lh_config) { double }
        let(:attributes) do
          {
            veteran: {
              address: {
                addressLine1: '936 Gus Points',
                city: 'Watersborough',
                countryCode: 'US',
                stateCode: 'CO',
                zipCode: '36090'
              }
            },
            recordConsent: true,
            consentLimits: %w[DRUG_ABUSE ALCOHOLISM HIV SICKLE_CELL],
            serviceOrganization: {
              poaCode: '095',
              registrationNumber: '999999999999'
            }
          }
        end
        let(:expected_data) { { data: { attributes: } } }
        let(:expected_response) do
          {
            'data' => {
              'id' => '12beb731-3440-44d2-84ba-473bd75201aa',
              'type' => 'organization',
              'attributes' => {
                'code' => '095',
                'name' => 'Italian American War Veterans of the US, Inc.',
                'phoneNumber' => '440-233-6527'
              }
            }
          }
        end

        context 'successful submit' do
          it 'submits the correct data to lighthouse' do
            @service = BenefitsClaims::Service.new('1012666183V089914')
            VCR.use_cassette(
              'lighthouse/benefits_claims/power_of_attorney_decision/202_response',
              match_requests_on: %i[method uri headers body]
            ) do
              expect(
                @service.submit2122(attributes, 'lh_client_id', 'key_path').body
              ).to eq expected_response
            end
          end
        end

        context 'rep does not have poa for veteran' do
          it 'returns a not_found response' do
            @service = BenefitsClaims::Service.new('1012666183V089914')
            VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_decision/404_response') do
              expect do
                @service.submit2122(attributes, 'lh_client_id', 'key_path')
              end.to raise_error(Common::Exceptions::ResourceNotFound)
            end
          end
        end
      end
    end
  end
end
