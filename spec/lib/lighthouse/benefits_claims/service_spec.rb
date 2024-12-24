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
            expect(response['data'].length).to eq(5)
          end
        end

        it 'has overriden PMR Pending tracked items to the NEEDED_FROM_OTHERS status and readable name' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            response = @service.get_claims
            # In the cassette, the status is NEEDED_FROM_YOU
            expect(response.dig('data', 0, 'attributes', 'trackedItems', 0, 'status')).to eq('NEEDED_FROM_OTHERS')
            expect(response.dig('data', 0, 'attributes', 'trackedItems', 0, 'displayName'))
              .to eq('Private Medical Record')
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

      describe '#submit2122' do
        body =  {
          "veteran": {
            "address": {
              "addressLine1": "123",
              "city": "city",
              "stateCode": "OR",
              "countryCode": "US",
              "zipCode": "12345"
            }
          },
          "serviceOrganization": {
            "poaCode": "083",
            "registrationNumber": "999999999999"
          }
        }

        lighthouse_client_id = "abcdefgh"

        context 'when there is valid params' do
          it "returns data" do
            response = @service.submit2122(body, lighthouse_client_id)
            data = JSON.parse(response.body)["data"]
            expect(response.status).to eq(202)
            expect(data["id"]).to eq("20da46c4-10d5-4985-8113-db92597ac85f")
            expect(data["attributes"]["name"]).to eq("083 - DISABLED AMERICAN VETERANS")
            expect(data["attributes"]["phoneNumber"]).to eq("555-555-5555")
          end
        end

        context 'when you are not authorized' do
          it "returns a 401 error" do
            response = @service.submit2122(body)
            errors = JSON.parse(response.body)["errors"]
            expect(response.status).to eq(401)
            expect(errors[0]["title"]).to eq("Not authorized")
            expect(errors[0]["status"]).to eq("401")
            expect(errors[0]["detail"]).to eq("Not authorized")
          end
        end

        context 'when the resource does not exist' do
          it "returns a 404 error" do
            invalid_body = body.dup
            invalid_body["serviceOrganization"]["poaCode"] = "082"
            invalid_body["serviceOrganization"]["registrationNumber"] = "999999999998"
            response = @service.submit2122(invalid_body, lighthouse_client_id)
            errors = JSON.parse(response.body)["errors"]
            expect(response.status).to eq(404)
            expect(errors[0]["title"]).to eq("Resource not found")
            expect(errors[0]["status"]).to eq("404")
            expect(errors[0]["detail"]).to eq("Could not find an Accredited Representative with registration number: 999999999998 and poa code: 082")
          end
        end

        context 'when the payload has incorrect params' do
          it "returns a 422 error" do
            invalid_body = body.dup
            invalid_body["serviceOrganization"].delete(:poaCode)
            response = @service.submit2122(invalid_body, lighthouse_client_id)
            errors = JSON.parse(response.body)["errors"]
            expect(response.status).to eq(422)
            expect(errors[0]["title"]).to eq("Unprocessable entity")
            expect(errors[0]["status"]).to eq("422")
            expect(errors[0]["detail"]).to eq("The property /serviceOrganization did not contain the required key poaCode")
            expect(errors[0]["source"]["pointer"]).to eq("data/attributes/serviceOrganization")
          end
        end

        context 'when the payload is too big' do
          it "returns a 413 error" do
            invalid_body = body.dup
            extra_chars = "A" * 200 
            invalid_body["serviceOrganization"]["registrationNumber"] += extra_chars
            response = @service.submit2122(invalid_body, lighthouse_client_id)
            body = JSON.parse(response.body)
            expect(response.status).to eq(413)
            expect(body["message"]).to eq("Request size limit exceeded")
          end
        end
      end
    end
  end
end
