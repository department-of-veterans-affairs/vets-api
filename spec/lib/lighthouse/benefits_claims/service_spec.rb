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
        it 'when given a full request body, posts to the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response') do
            response = @service.submit526({ data: { attributes: {} } }, '', '', { body_only: true })
            expect(response).to eq('1234567890')
          end
        end

        it 'when given a only the form data in the request body, posts to the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response') do
            response = @service.submit526({}, '', '', { body_only: true })
            expect(response).to eq('1234567890')
          end
        end

        it 'returns only the response body' do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response') do
            body = @service.submit526({ data: { attributes: {} } }, '', '', { body_only: true })
            expect(body).to eq('1234567890')
          end
        end

        it 'returns the whole response' do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response') do
            raw_response = @service.submit526({}, '', '', { body_only: false })
            raw_response_struct = OpenStruct.new({
                                                   body: { claim_id: raw_response.body },
                                                   status: raw_response.status
                                                 })
            response = EVSS::DisabilityCompensationForm::FormSubmitResponse
                       .new(raw_response_struct.status, raw_response_struct)

            expect(response.status).to eq(200)
            expect(response.claim_id).to eq(1_234_567_890)
          end
        end
      end
    end
  end
end
