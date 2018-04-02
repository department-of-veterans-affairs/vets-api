# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  let(:user) { build(:disabilities_compensation_user) }
  subject { described_class.new(user) }

  describe '#get_rated_disabilities' do
    context 'with a valid evss response' do
      it 'returns a rated disabilities response object' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          response = subject.get_rated_disabilities
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
          expect(response.rated_disabilities.count).to eq 2
          expect(response.rated_disabilities.first.special_issues).to be_an Array
          expect(response.rated_disabilities.first.special_issues.first).to be_an EVSS::DisabilityCompensationForm::SpecialIssue
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'should log an error and raise GatewayTimeout' do
        expect(Rails.logger).to receive(:error).with(/Timeout/)
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rated_disabilities.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rated_disabilities.total')
        expect { subject.get_rated_disabilities }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#submit_form' do
    context 'with valid input' do
      let(:valid_form_content) {{
        "form526": {
          "veteran": {
            "emailAddress": "string",
            "alternateEmailAddress": "string",
            "mailingAddress": {
              "addressLine1": "string",
              "addressLine2": "string",
              "addressLine3": "string",
              "city": "string",
              "state": "IL",
              "zipFirstFive": "11111",
              "zipLastFour": "1111",
              "country": "string",
              "militaryStateCode": "AA",
              "militaryPostOfficeTypeCode": "APO",
              "type": "DOMESTIC"
            },
            "forwardingAddress": {
              "addressLine1": "string",
              "addressLine2": "string",
              "addressLine3": "string",
              "city": "string",
              "state": "IL",
              "zipFirstFive": "11111",
              "zipLastFour": "1111",
              "country": "string",
              "militaryStateCode": "AA",
              "militaryPostOfficeTypeCode": "APO",
              "type": "DOMESTIC",
              "effectiveDate": "2018-03-29T18:50:03.014Z"
            },
            "primaryPhone": {
              "areaCode": "202",
              "phoneNumber": "4561111"
            },
            "homelessness": {
              "hasPointOfContact": false,
            },
            "serviceNumber": "string"
          },
          "attachments": [],
          "militaryPayments": {
            "payments": [],
            "receiveCompensationInLieuOfRetired": false,
            "receivingInactiveDutyTrainingPay": false,
            "waveBenifitsToRecInactDutyTraiPay": false
          },
          "directDeposit": {
            "accountType": "CHECKING",
            "accountNumber": "1234",
            "bankName": "string",
            "routingNumber": "123456789"
          },
          "serviceInformation": {
            "servicePeriods": [
              {
                "serviceBranch": "string",
                "activeDutyBeginDate": "2018-03-29T18:50:03.015Z",
                "activeDutyEndDate": "2018-03-29T18:50:03.015Z"
              }
            ],
            "reservesNationalGuardService": {
              "title10Activation": {
                "title10ActivationDate": "2018-03-29T18:50:03.015Z",
                "anticipatedSeparationDate": "2018-03-29T18:50:03.015Z"
              },
              "obligationTermOfServiceFromDate": "2018-03-29T18:50:03.015Z",
              "obligationTermOfServiceToDate": "2018-03-29T18:50:03.015Z",
              "unitName": "string",
              "unitPhone": {
                "areaCode": "202",
                "phoneNumber": "4561111"
              }
            },
            "servedInCombatZone": true,
            "separationLocationName": "OTHER",
            "separationLocationCode": "SOME VALUE",
            "alternateNames": [
              {
                "firstName": "string",
                "middleName": "string",
                "lastName": "string"
              }
            ],
            "confinements": [
              {
                "confinementBeginDate": "2018-03-29T18:50:03.015Z",
                "confinementEndDate": "2018-03-29T18:50:03.015Z",
                "verifiedIndicator": false
              }
            ]
          },
          "disabilities": [
            {
              "diagnosticText": "Diabetes mellitus",
              "disabilityActionType": "INCREASE",
              "decisionCode": "SVCCONNCTED",
              "specialIssues": [
                {
                  "code": "TRM",
                  "name": "Personal Trauma PTSD"
                }
              ],
              "ratedDisabilityId": "0",
              "ratingDecisionId": 63655,
              "diagnosticCode": 5235,
              "secondaryDisabilities": [
                {
                  "decisionCode": "",
                  "ratedDisabilityId": "",
                  "diagnosticText": "string",
                  "disabilityActionType": "NONE"
                }
              ]
            }
          ],
          "treatments": [],
          "specialCircumstances": [
            {
              "name": "string",
              "code": "string",
              "needed": false
            }
          ]
        }
      }.to_json}

      it 'returns a form submit response object' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          response = subject.submit_form(valid_form_content)
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::FormSubmitResponse
          expect(response.claim_id).to be_an Integer
        end
      end
    end

  end
end
