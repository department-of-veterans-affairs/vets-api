# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'

RSpec.describe 'ClaimsApi::V2::Veterans::526', type: :request do
  let(:scopes) { %w[claim.write claim.read] }
  let(:claim_date) { Time.find_zone!('Central Time (US & Canada)').today }
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: 'Wesley',
      last_name: 'Ford',
      middle_name: 'John',
      birth_date: '19630211',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796043735',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1012832025V743496',
        profile: OpenStruct.new(ssn: '796043735')
      )
    )
  end

  before do
    Timecop.freeze(Time.zone.now)
    allow_any_instance_of(ClaimsApi::EVSSService::Base).to receive(:submit).and_return OpenStruct.new(claimId: 1337)
  end

  after do
    Timecop.return
  end

  describe '#526', vcr: 'claims_api/disability_comp' do
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:veteran_id) { '1013062086V794840' }

    describe 'submit', skip: 'Disabling tests for deactivated /veterans/{veteranId}/526 endpoint' do
      let(:submit_path) { "/services/claims/v2/veterans/#{veteran_id}/526" }
      let(:validate_path) { "/services/claims/v2/veterans/#{veteran_id}/526/validate" }

      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                post submit_path, params: data, headers: auth_header

                expected = 'http://www.example.com/services/claims/v2/veterans/1013062086V794840/claims/'
                expect(response).to have_http_status(:accepted)
                expect(response.location).to include(expected)
              end
            end

            it 'calls shared validation' do
              mock_ccg(scopes) do |auth_header|
                expect_any_instance_of(ClaimsApi::V2::DisabilityCompensationValidation)
                  .to receive(:validate_form_526_submission_values)
                post validate_path, params: data, headers: auth_header
              end
            end
          end
        end
      end

      describe 'with updated headers requirements' do
        let(:no_edipi_target_veteran) do
          OpenStruct.new(
            icn: '1012832025V743496',
            first_name: 'Wesley',
            last_name: 'Ford',
            birth_date: '19630211',
            loa: { current: 3, highest: 3 },
            edipi: nil,
            ssn: '796043735',
            participant_id: '600061742',
            mpi: OpenStruct.new(
              icn: '1012832025V743496',
              profile: OpenStruct.new(ssn: '796043735')
            )
          )
        end

        context 'without the EDIPI value present' do
          it 'does not allow the submit to occur' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
                .to receive(:target_veteran).and_return(no_edipi_target_veteran)
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq(
                "Unable to locate Veteran's EDIPI in Master Person Index (MPI). " \
                'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
              )
            end
          end
        end
      end

      context 'handling for missing veteran first and last name' do
        context 'without the first name present' do
          it 'does not allow the submit to occur' do
            mock_ccg(scopes) do |auth_header|
              target_veteran.first_name = ''
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq('Missing first name')
            end
          end
        end

        context 'without the last name present' do
          it 'does not allow the submit to occur' do
            mock_ccg(scopes) do |auth_header|
              target_veteran.last_name = ''
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq('Missing last name')
            end
          end
        end
      end

      describe 'schema catches claimProcessType error' do
        context 'when something other than an enum option is used' do
          let(:claim_process_type) { 'claim_test' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              data = json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when an empty string is provided' do
          let(:claim_process_type) { ' ' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              data = json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe 'validation of claimant mailing address elements' do
        context 'when no mailing address data is found' do
          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress'] = {}
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe 'veteranIdentification' do
        context 'when the phone has non-digits included' do
          let(:telephone) { '123456789X' }

          it 'responds with unprocessable request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['veteranNumber']['telephone'] = telephone
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the internationalTelephone has non-digits included' do
          let(:international_telephone) { '+44 20 1234 5678' }

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['veteranNumber']['internationalTelephone'] =
                international_telephone
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the zipFirstFive has non-digits included' do
          let(:zip_first_five) { '1234X' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['zipFirstFive'] = zip_first_five
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the zipLastFour has non-digits included' do
          let(:zip_last_four) { '123X' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['zipLastFour'] = zip_last_four
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the apartmentOrUnitNumber exceeds the max length' do
          let(:apartment_or_unit_number) { '123456' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['apartmentOrUnitNumber'] =
                apartment_or_unit_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the numberAndStreet exceeds the max length' do
          let(:number_and_street) { '1234567890abcdefghijklmnopqrstuvwxyz' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['numberAndStreet'] =
                number_and_street
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the city exceeds the max length' do
          let(:city) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['city'] = city
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the state has non-alphabetic characters' do
          let(:state) { '!@#$%^&*()_+-=' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['mailingAddress']['state'] = state
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the vaFileNumber exceeds the max length' do
          let(:va_file_number) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['vaFileNumber'] = va_file_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the vaFileNumber is missing' do
          let(:va_file_number) { nil }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['vaFileNumber'] = va_file_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when currentVaEmployee is a non-boolean value' do
          let(:current_va_employee) { 'negative' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['currentVaEmployee'] =
                current_va_employee
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when currentVaEmployee is null' do
          let(:current_va_employee) { nil }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['currentVaEmployee'] =
                current_va_employee
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when currentVaEmployee is absent' do
          let(:veteran_identification) do
            {
              serviceNumber: '123456789',
              veteranNumber: {
                telephone: '5555555555',
                internationalTelephone: '+44 20 1234 5678'
              },
              mailingAddress: {
                addressLine1: '1234 Couch Street',
                addressLine2: 'Unit 4',
                addressLine3: 'Room 1',
                city: 'Portland',
                state: 'OR',
                country: 'USA',
                zipFirstFive: '41726',
                zipLastFour: '1234'
              },
              emailAddress: {
                email: 'valid@somedomain.com',
                agreeToEmailRelatedToClaim: true
              }
            }
          end

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification'] =
                veteran_identification
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when serviceNumber exceeds max length' do
          let(:service_number) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['serviceNumber'] = service_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when serviceNumber is null' do
          let(:service_number) { nil }

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['serviceNumber'] = service_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when email exceeds max length of 80 characters' do
          let(:email) { '123456789011121314151617abcdefghijklmnopqrstuvwxyz@someinordiantelylongdomain.com' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['emailAddress']['email'] = email
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'][0]['detail']).to include(
                'The property /veteranIdentification/emailAddress/email did not match the ' \
                'following requirements:'
              )
            end
          end
        end

        context 'when email TLD is over 3 characters' do
          let(:email) { 'valid@some.extralongtld' }

          it 'responds with accepted' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['emailAddress']['email'] = email
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when email TLD is under 2 characters' do
          let(:email) { '1234567890abcd@some.v' }

          it 'responds with unprocessable entity' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['emailAddress']['email'] = email
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'][0]['detail']).to include(
                'The property /veteranIdentification/emailAddress/email did not match the ' \
                'following requirements:'
              )
            end
          end
        end

        context 'when agreeToEmailRelatedToClaim is a non-boolean value' do
          let(:agree_to_email_related_to_claim) { 'negative' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['veteranIdentification']['emailAddress']['agreeToEmailRelatedToClaim'] =
                agree_to_email_related_to_claim
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      context 'when agreeToEmailRelatedToClaim is null' do
        let(:agree_to_email_related_to_claim) { nil }

        it 'succeeds' do
          mock_ccg(scopes) do |auth_header|
            json = JSON.parse(data)
            json['data']['attributes']['veteranIdentification']['emailAddress']['agreeToEmailRelatedToClaim'] =
              agree_to_email_related_to_claim
            data = json.to_json
            post submit_path, params: data, headers: auth_header
            expect(response).to have_http_status(:accepted)
          end
        end
      end

      describe 'Validation of claimant homeless elements' do
        context "when 'currentlyHomeless' and 'riskOfBecomingHomeless' are both provided" do
          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'LIVING_IN_A_HOMELESS_SHELTER',
                otherDescription: 'community help center'
              }
              params['data']['attributes']['homeless']['riskOfBecomingHomeless'] = {
                livingSituationOptions: 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
                otherDescription: 'community help center'
              }
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'].length).to eq(1)
              expect(response_body['errors'][0]['detail']).to eq(
                "Must define only one of 'homeless/currentlyHomeless' or " \
                "'homeless/riskOfBecomingHomeless'"
              )
            end
          end
        end

        context "when only 'isCurrentlyHomeless' and 'isAtRiskOfBecomingHomeless' are provided" do
          it 'responds with a 200' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless'] = {
                isCurrentlyHomeless: false,
                isAtRiskOfBecomingHomeless: false
              }
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:success)
            end
          end
        end
      end

      context "when neither 'currentlyHomeless' nor 'riskOfBecomingHomeless' is provided" do
        context "when 'pointOfContact' is provided" do
          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless'] = {}
              params['data']['attributes']['homeless'] = {
                pointOfContact: 'Jane Doe',
                pointOfContactNumber: {
                  telephone: '1234567890'
                }
              }
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'].length).to eq(1)
              expect(response_body['errors'][0]['detail']).to eq(
                "If 'homeless/pointOfContact' is defined, then one of " \
                "'homeless/currentlyHomeless' or 'homeless/riskOfBecomingHomeless'" \
                ' is required'
              )
            end
          end
        end

        context "when 'pointOfContact' is not provided" do
          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                otherDescription: 'community help center'
              }
              params['data']['attributes']['homeless'].delete('pointOfContact')
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'].length).to eq(1)
              expect(response_body['errors'][0]['detail']).to eq(
                "If one of 'homeless/currentlyHomeless' or 'homeless/riskOfBecomingHomeless' is" \
                " defined, then 'homeless/pointOfContact' is required"
              )
            end
          end
        end
      end

      context "when either 'currentlyHomeless' or 'riskOfBecomingHomeless' is provided" do
        context "when 'pointOfContactNumber' 'telephone' contains alphabetic characters" do
          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                otherDescription: 'community help center'
              }
              params['data']['attributes']['homeless']['pointOfContactNumber']['telephone'] = 'xxxyyyzzzz'
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context "when 'pointOfContactNumber' 'internationalTelephone' contains alphabetic characters" do
          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                otherDescription: 'community help center'
              }
              params['data']['attributes']['homeless']['pointOfContactNumber']['internationalTelephone'] =
                '+44 20 1234 5678'
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context "when 'pointOfContactNumber' 'internationalTelephone' contains more than 25 characters" do
          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                otherDescription: 'community help center'
              }
              params['data']['attributes']['homeless']['pointOfContactNumber']['internationalTelephone'] =
                '+44 20 1234 56789111111111'
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when 526 form indicates a homeless situation' do
          it 'sets the homeless flash' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless']['currentlyHomeless'] = {
                homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                otherDescription: 'community help center'
              }
              post submit_path, params: params.to_json, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)
              expect(aec.flashes).to eq(%w[Homeless])
            end
          end
        end

        context 'when 526 form indicates an at-risk of homelessness situation' do
          let(:homeless) do
            {
              pointOfContact: 'john stewart',
              pointOfContactNumber: {
                telephone: '5555555555',
                internationalTelephone: '+44 20 1234 5678'
              }
            }
          end

          it 'sets the hardship flash' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['homeless'] = homeless
              params['data']['attributes']['homeless']['riskOfBecomingHomeless'] = {
                livingSituationOptions: 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
                otherDescription: 'other living situation'
              }
              post submit_path, params: params.to_json, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)
              expect(aec.flashes).to eq(%w[Hardship])
            end
          end
        end
      end

      describe 'Validation of toxicExposure elements' do
        context 'when the other_locations_served does not match the regex' do
          let(:other_locations_served) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['herbicideHazardService']['otherLocationsServed'] =
                other_locations_served
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the additional_exposures does not match the regex' do
          let(:additional_exposures) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['additionalHazardExposures']['additionalExposures'] =
                additional_exposures
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the specify_other_exposures does not match the regex' do
          let(:specify_other_exposures) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

          it 'responds with a accepted' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['additionalHazardExposures']['specifyOtherExposures'] =
                specify_other_exposures
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the exposure_location does not match the regex' do
          let(:exposure_location) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

          it 'responds with a accepted' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['multipleExposures'][0]['exposureLocation'] =
                exposure_location
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the hazard_exposed_to does not match the regex' do
          let(:hazard_exposed_to) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

          it 'responds with a bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['multipleExposures'][0]['hazardExposedTo'] =
                hazard_exposed_to
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when gulf war service is set to No, and service dates are not present' do
          let(:gulf_war_hazard_service) { 'NO' }
          let(:service_dates) { nil }

          it 'responds with accepted' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['servedInGulfWarHazardLocations'] =
                gulf_war_hazard_service
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates'] =
                service_dates
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when gulf war service is set to YES, and service dates are not present' do
          let(:gulf_war_hazard_service) { 'YES' }
          let(:service_dates) { nil }

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['servedInGulfWarHazardLocations'] =
                gulf_war_hazard_service
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates'] =
                service_dates
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when gulf war service is set to YES, and service dates only have beginDate' do
          let(:gulf_war_hazard_service) { 'YES' }
          let(:service_dates) do
            {
              beginDate: '2005-01',
              endDate: nil
            }
          end

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['servedInGulfWarHazardLocations'] =
                gulf_war_hazard_service
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates'] =
                service_dates
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when gulf war service is set to YES, and service dates only have endDate' do
          let(:gulf_war_hazard_service) { 'YES' }
          let(:service_dates) do
            {
              beginDate: nil,
              endDate: '2005-01'
            }
          end

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['servedInGulfWarHazardLocations'] =
                gulf_war_hazard_service
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates'] =
                service_dates
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when a federalActivation date is invalid' do
          let(:begin_date) { '2017-02-29' }

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates']['beginDate'] =
                begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when a federalActivation date is valid' do
          let(:end_date) { '2017-02-28' }

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates']['endDare'] = end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when gulf war service is set to YES, and service dates are not formatted correctly' do
          let(:gulf_war_hazard_service) { 'YES' }
          let(:service_dates) do
            {
              beginDate: '199907',
              endDate: '2005-01'
            }
          end

          it 'responds with unprocessable entity' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['servedInGulfWarHazardLocations'] =
                gulf_war_hazard_service
              json['data']['attributes']['toxicExposure']['gulfWarHazardService']['serviceDates'] =
                service_dates
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      context 'tracking PACT act claims' do
        context 'when is a PACT claim' do
          it 'tracks the claim count' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'][0]['isRelatedToToxicExposure'] = true
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              ClaimsApi::AutoEstablishedClaim.find(claim_id)
              submissions = ClaimsApi::AutoEstablishedClaim.find(claim_id).submissions
              expect(submissions.size).to be <= 1
            end
          end
        end

        context 'when it is not a PACT claim' do
          let(:disabilities) do
            [{
              disabilityActionType: 'NEW',
              name: 'Traumatic Brain Injury',
              classificationCode: '9020',
              serviceRelevance: 'ABCDEFG',
              approximateDate: '2018-11-03',
              ratedDisabilityId: 'ABCDEFGHIJKLMNOPQRSTUVWX',
              diagnosticCode: 9020,
              secondaryDisabilities: [
                {
                  name: 'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders',
                  disabilityActionType: 'SECONDARY',
                  serviceRelevance: 'ABCDEFGHIJKLMNOPQ',
                  classificationCode: '9010',
                  approximateDate: '2018-12-03',
                  exposureOrEventOrInjury: 'EXPOSURE'
                }
              ],
              isRelatedToToxicExposure: false,
              exposureOrEventOrInjury: 'EXPOSURE'
            }]
          end
          let(:treatments) do
            [
              {
                center: {
                  name: 'Center One',
                  state: 'GA',
                  city: 'Decatur'
                },
                treatedDisabilityNames: ['Traumatic Brain Injury',
                                         'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders'],
                beginDate: '2009-03'
              }
            ]
          end

          it 'tracks the claim count' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              ClaimsApi::AutoEstablishedClaim.find(claim_id)
              submissions = ClaimsApi::AutoEstablishedClaim.find(claim_id).submissions
              expect(submissions.size).to be(0)
            end
          end
        end

        context 'when it is not a PACT claim because the disabilityActionType is set to "INCREASE"' do
          let(:disabilities) do
            [{
              disabilityActionType: 'INCREASE',
              name: 'Traumatic Brain Injury',
              classificationCode: '9020',
              serviceRelevance: 'ABCDEFG',
              approximateDate: '2018-11-03',
              ratedDisabilityId: 'ABCDEFGHIJKLMNOPQRSTUVWX',
              diagnosticCode: 9020,
              isRelatedToToxicExposure: true,
              exposureOrEventOrInjury: 'EXPOSURE'
            }]
          end
          let(:treatments) do
            [
              {
                center: {
                  name: 'Center One',
                  state: 'GA',
                  city: 'Decatur'
                },
                treatedDisabilityNames: ['Traumatic Brain Injury'],
                beginDate: '2009-03'
              }
            ]
          end

          it 'tracks the claim count' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              ClaimsApi::AutoEstablishedClaim.find(claim_id)
              submissions = ClaimsApi::AutoEstablishedClaim.find(claim_id).submissions
              expect(submissions.size).to be(0)
            end
          end
        end

        context 'when it is not a PACT claim because the disabilityActionType is set to "NONE"' do
          let(:disabilities) do
            [{
              disabilityActionType: 'NONE',
              name: 'Traumatic Brain Injury',
              classificationCode: '9020',
              serviceRelevance: 'ABCDEFG',
              approximateDate: '2018-11-03',
              ratedDisabilityId: 'ABCDEFGHIJKLMNOPQRSTUVWX',
              diagnosticCode: 9020,
              secondaryDisabilities: [
                {
                  name: 'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders',
                  disabilityActionType: 'SECONDARY',
                  serviceRelevance: 'ABCDEFGHIJKLMNOPQ',
                  classificationCode: '9010',
                  approximateDate: '2018-12-03',
                  exposureOrEventOrInjury: 'EXPOSURE'
                }
              ],
              isRelatedToToxicExposure: true,
              exposureOrEventOrInjury: 'EXPOSURE'
            }]
          end
          let(:treatments) do
            [
              {
                center: {
                  name: 'Center One',
                  state: 'GA',
                  city: 'Decatur'
                },
                treatedDisabilityNames: ['Traumatic Brain Injury',
                                         'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders'],
                beginDate: '2009-03'
              }
            ]
          end

          it 'tracks the claim count' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              claim_id = response.location.split('/')[-1].to_s
              ClaimsApi::AutoEstablishedClaim.find(claim_id)
              submissions = ClaimsApi::AutoEstablishedClaim.find(claim_id).submissions
              expect(submissions.size).to be(0)
            end
          end
        end
      end

      describe 'specialIssues claims' do
        let(:disabilities) do
          [{
            disabilityActionType: 'INCREASE',
            name: 'Traumatic Brain Injury',
            classificationCode: '9020',
            serviceRelevance: 'ABCDEFG',
            approximateDate: '2018-11-03',
            ratedDisabilityId: 'ABCDEFGHIJKLMNOPQRSTUVWX',
            diagnosticCode: 9020,
            specialIssues: ['EMP'],
            secondaryDisabilities: [
              {
                name: 'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders',
                disabilityActionType: 'SECONDARY',
                serviceRelevance: 'ABCDEFGHIJKLMNOPQ',
                classificationCode: '9010',
                approximateDate: '2018-12-03',
                exposureOrEventOrInjury: 'EXPOSURE'
              }
            ],
            isRelatedToToxicExposure: true,
            exposureOrEventOrInjury: 'EXPOSURE'
          }]
        end
        let(:treatments) do
          [
            {
              center: {
                name: 'Center One',
                state: 'GA',
                city: 'Decatur'
              },
              treatedDisabilityNames: ['Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders'],
              beginDate: '2009-03'
            }
          ]
        end

        context 'when specialIssues contains "POW" but disabilityActionType is set to "INCREASE"' do
          let(:special_issues) { ['POW'] }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when specialIssues contains "EMP" but disabilityActionType is set to "INCREASE"' do
          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when specialIssues contains "POW" and disabilityActionType is set to "NEW"' do
          let(:special_issues) { ['POW'] }
          let(:disability_action_type) { 'NEW' }

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
              json['data']['attributes']['disabilities'][0]['disabilityActionType'] = disability_action_type
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when specialIssues contains "POW" & "EMP" and disabilityActionType is set to "NEW"' do
          let(:special_issues) { %w[POW EMP] }
          let(:disability_action_type) { 'NEW' }

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
              json['data']['attributes']['disabilities'][0]['disabilityActionType'] = disability_action_type
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when specialIssues are added to a secondary disability' do
          let(:special_issues) { ['POW'] }
          let(:disability_action_type) { 'NEW' }

          it 'responds with a 404' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
              json['data']['attributes']['disabilities'][0]['disabilityActionType'] = disability_action_type
              json['data']['attributes']['disabilities'][0][:secondaryDisabilities][0]['specialIssues'] = special_issues
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when specialIssues contains "POW" and serviceInformation.confinements is blank' do
          let(:confinements) do
            []
          end
          let(:special_issues) { ['POW'] }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'] = disabilities
              json['data']['attributes']['treatments'] = treatments
              json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
              json['data']['attributes']['serviceInformation']['confinements'] = confinements

              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe "'servicePay validations'" do
        describe 'retired pay validations' do
          describe "'receivingMilitaryRetiredPay' and 'futureMilitaryRetiredPay' validations" do
            let(:service_pay_attribute) do
              {
                receivingMilitaryRetiredPay: receiving,
                futureMilitaryRetiredPay: future,
                futureMilitaryRetiredPayExplanation: 'Some explanation',
                militaryRetiredPay: {
                  branchOfService: 'Air Force'
                }
              }
            end

            context "when 'receivingMilitaryRetiredPay' and 'futureMilitaryRetiredPay' are equal but not 'nil'" do
              context "when both are 'true'" do
                let(:receiving) { 'YES' }
                let(:future) { 'YES' }

                it 'responds with a 422bad request' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end

              context "when both are 'false'" do
                let(:receiving) { 'NO' }
                let(:future) { 'NO' }

                it 'responds with a 422' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end

            context "when 'receivingMilitaryRetiredPay' and 'futureMilitaryRetiredPay' are not equal" do
              context "when 'receivingMilitaryRetiredPay' is 'false' and 'futureMilitaryRetiredPay' is 'true'" do
                let(:receiving) { 'NO' }
                let(:future) { 'YES' }

                it 'responds with a 202' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:accepted)
                  end
                end
              end

              context "when 'receivingMilitaryRetiredPay' is 'YES' and 'futureMilitaryRetiredPay' is 'NO'" do
                let(:receiving) { 'YES' }
                let(:future) { 'NO' }

                it 'responds with a 202' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:accepted)
                  end
                end
              end
            end
          end

          describe "'payment'" do
            let(:service_pay_attribute) do
              {
                receivingMilitaryRetiredPay: 'YES',
                futureMilitaryRetiredPay: 'NO',
                militaryRetiredPay: {
                  branchOfService: 'Air Force',
                  monthlyAmount: military_retired_payment_amount
                }
              }
            end

            context "when 'monthlyAmount' is below the minimum" do
              let(:military_retired_payment_amount) { 0 }

              it 'responds with an unprocessable entity' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'monthlyAmount' is above the maximum" do
              let(:military_retired_payment_amount) { 1_000_000 }

              it 'responds with an unprocessable entity' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'monthlyAmount' is within limits" do
              let(:military_retired_payment_amount) { 100 }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end

          describe "'futurePayExplanation'" do
            context "when 'futureMilitaryRetiredPay' is 'true'" do
              let(:future_military_retired_pay) { 'YES' }

              context "when 'futureMilitaryRetiredPayExplanation' is not provided" do
                let(:service_pay_attribute) do
                  {
                    receivingMilitaryRetiredPay: 'NO',
                    futureMilitaryRetiredPay: future_military_retired_pay,
                    militaryRetiredPay: {
                      branchOfService: 'Air Force'
                    }
                  }
                end

                it 'responds with an unprocessable entity' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end

              context "when 'futureMilitaryRetiredPayExplanation' is provided" do
                let(:service_pay_attribute) do
                  {
                    receivingMilitaryRetiredPay: 'NO',
                    futureMilitaryRetiredPay: future_military_retired_pay,
                    futureMilitaryRetiredPayExplanation: 'Retiring soon.',
                    militaryRetiredPay: {
                      branchOfService: 'Air Force'
                    }
                  }
                end

                it 'responds with a 202' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:accepted)
                  end
                end
              end
            end
          end
        end

        describe "'servicePay.separationSeverancePay' validations" do
          describe "'payment'" do
            let(:service_pay_attribute) do
              {
                receivedSeparationOrSeverancePay: 'YES',
                separationSeverancePay: {
                  datePaymentReceived: (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                  branchOfService: 'Air Force',
                  preTaxAmountReceived: separation_payment_amount
                }
              }
            end

            context "when 'preTaxAmountReceived' is below the minimum" do
              let(:separation_payment_amount) { 0 }

              it 'responds with an unprocessable entity' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'preTaxAmountReceived' is above the maximum" do
              let(:separation_payment_amount) { 1_000_000 }

              it 'responds with an unprocessable entity' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'preTaxAmountReceived' is within limits" do
              let(:separation_payment_amount) { 100 }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end

          describe "'datePaymentReceived'" do
            let(:service_pay_attribute) do
              {
                receivedSeparationOrSeverancePay: 'YES',
                separationSeverancePay: {
                  datePaymentReceived: received_date,
                  branchOfService: 'Air Force',
                  preTaxAmountReceived: 100
                }
              }
            end

            context "when 'datePaymentReceived' is not in the past" do
              let(:received_date) { (Time.zone.today + 1.day).strftime('%Y-%m-%d') }

              it 'responds with a 422' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'datePaymentReceived' is in the past" do
              let(:received_date) { (Time.zone.today - 1.year).strftime('%Y-%m-%d') }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context "when 'datePaymentReceived' is not in the past but is approximate (YYYY-MM)" do
              let(:received_date) { (Time.zone.today + 1.month).strftime('%Y-%m') }

              it 'responds with a 422' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'datePaymentReceived' is in the past but is approximate (YYYY-MM)" do
              let(:received_date) { (Time.zone.today - 1.year).strftime('%Y-%m') }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context "when 'datePaymentReceived' is not in the past but is approximate (YYYY)" do
              let(:received_date) { (Time.zone.today + 1.year).strftime('%Y') }

              it 'responds with a 422' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context "when 'datePaymentReceived' is in the past but is approximate (YYYY)" do
              let(:received_date) { (Time.zone.today - 1.year).strftime('%Y') }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end
        end
      end

      describe 'Validating treatment beginDate and first service period beginDate' do
        def update_json_and_submit(updated_json_lambda)
          mock_ccg(scopes) do |auth_header|
            json = JSON.parse(data)
            updated_json = updated_json_lambda.call(json)
            post submit_path, params: updated_json.to_json, headers: auth_header
            response
          end
        end

        context 'when treatment beginDate has a YYYY-MM pattern' do
          it 'returns a 202 when the treatment beginDate is after the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2009-03'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-01-01'
                json
              end
            )
            expect(response).to have_http_status(:accepted)
          end

          it 'returns a 202 when the treatment beginDate is the same as the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2008-01'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-01-31'
                json
              end
            )
            expect(response).to have_http_status(:accepted)
          end

          it 'returns a 422 when the treatment beginDate is before the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2007-12'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-01-01'
                json
              end
            )
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'returns a 422 when the treatment beginDate is a month before the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2008-07'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-08-01'
                json
              end
            )
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when treatment beginDate has a YYYY pattern' do
          it 'returns a 202 when the treatment beginDate is after the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2009'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-01-01'
                json
              end
            )
            expect(response).to have_http_status(:accepted)
          end

          it 'returns a 202 when the treatment beginDate is the same year as the first service period beginDateDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2008'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-12-31'
                json
              end
            )
            expect(response).to have_http_status(:accepted)
          end

          it 'returns a 422 when the treatment beginDate is before the first service period beginDate' do
            response = update_json_and_submit(
              lambda do |json|
                json['data']['attributes']['treatments'][0]['beginDate'] = '2007'
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                  '2008-01-01'
                json
              end
            )
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      describe 'Validation of treatment elements' do
        context 'when treatments values are not submitted' do
          it 'returns a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['treatments'] = []
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when treatment beginDate is included and in the correct pattern' do
          it 'returns a 202' do
            mock_ccg(scopes) do |auth_header|
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when treatment beginDate is included and in the YYYY pattern' do
          let(:treatment_begin_date) { '2009' }

          it 'returns a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['treatments'][0]['beginDate'] = treatment_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'the begin date' do
          it 'is not after the first service period begin date it is unprocessable' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['treatments'][0]['beginDate'] = '2007-12'
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          it 'is after the first service period begin date, it succeeds' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end

          it 'is the wrong format it is unprocessable' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['treatments'][0]['beginDate'] = '2008-01-12'
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'it gets the signature from the headers and MPI' do
          it 'returns a 202, and gets the signature' do
            mock_ccg(scopes) do |auth_header|
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when treatment beginDate is in the wrong pattern' do
          let(:treatment_begin_date) { '1999/12/01' }
          let(:active_duty_begin_date) { '1981-11-15' }

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['treatments'][0]['beginDate'] = treatment_begin_date
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context "when 'treatment.beginDate' is not included" do
          it 'returns a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['treatments'][0]['beginDate'] = nil
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'validating treatment.centers' do
          context 'when the treatments.center.name' do
            context 'is a single character' do
              let(:treated_center_name) { '1' }

              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context 'has invalid characters in it' do
              let(:treated_center_name) { 'Center//// this $' }

              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context 'has more then 100 characters in it' do
              let(:treated_center_name) { (0...102).map { ('a'..'z').to_a[rand(26)] }.join }

              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context 'is a valid string of characters' do
              it 'returns a 202' do
                mock_ccg(scopes) do |auth_header|
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end

          context 'when the treatments.center.city' do
            context 'is a valid string of characters' do
              it 'returns a 202' do
                mock_ccg(scopes) do |auth_header|
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context 'has valid characters in it' do
              let(:treated_center_city) { 'LMNOP 6^7' }

              it 'returns a 202' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse data
                  json['data']['attributes']['treatments'][0]['center']['city'] = treated_center_city
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end

          context 'is null' do
            let(:treated_center_city) { nil }

            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse data
                json['data']['attributes']['treatments'][0]['center']['city'] = treated_center_city
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context 'when the treatments.center.state' do
            context 'is in the correct 2 letter format' do
              it 'returns a 202' do
                mock_ccg(scopes) do |auth_header|
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context 'is not in the correct 2 letter format' do
              let(:treated_center_state) { 'LMNOP' }

              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse data
                  json['data']['attributes']['treatments'][0]['center']['state'] = treated_center_state
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end

      describe 'Validation of service information elements' do
        context 'when elements are required conditionally' do
          context 'when reserves values are present but obligationTermsOfService is empty' do
            let(:empty_date) { '' }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
                tos = reserves['obligationTermsOfService']
                tos['beginDate'] = empty_date
                tos['endDate'] = empty_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'obligationTermsOfService beginDate is required but not present' do
            it 'returns a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
                tos = reserves['obligationTermsOfService']
                tos['beginDate'] = ''
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'obligationTermsOfService endDate is required but not present' do
            it 'returns a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
                tos = reserves['obligationTermsOfService']
                tos['endDate'] = ''
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when federalActivation is present anticipatedSeparationDate is required' do
            context 'when anticipatedSeparationDate is missing' do
              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  reserves = json['data']['attributes']['serviceInformation']
                  reserves['federalActivation']['anticipatedSeparationDate'] = ''
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context 'when federalActivation is present activationDate is required' do
            context 'when activationDate is missing' do
              it 'returns a 422' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  reserves = json['data']['attributes']['serviceInformation']
                  reserves['federalActivation']['activationDate'] = ''
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the serviceBranch is empty' do
          let(:service_branch) { '' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['serviceBranch'] =
                service_branch
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the serviceBranch is not in the BRD list' do
          let(:service_branch) { 'Rogue Force' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['serviceBranch'] =
                service_branch
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the serviceBranch is in the BRD list but does not match case' do
          let(:service_branch) { 'PUBLIC Health SERVICE' }

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['serviceBranch'] =
                service_branch
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the activeDutyBeginDate is after the activeDutyEndDate' do
          let(:active_duty_end_date) { '1979-01-01' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyBeginDate is not an actual date' do
          let(:active_duty_begin_date) { '2005-02-30' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              # make sure it is failing for the expected reason, do not need the whole text
              expect(response_body['errors'][0]['detail']).to include(
                "#{active_duty_begin_date} is not a valid date."
              )
            end
          end
        end

        context "when the activeDutyBeginDate is on or before the Veteran's 13th birthday" do
          let(:active_duty_begin_date) { '1904-01-01' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyBeginDate is not formatted correctly' do
          let(:active_duty_begin_date) { '01-01-2009' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyBeginDate is missing day portion of date' do
          let(:active_duty_begin_date) { '2009-01' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyEndDate is not formatted correctly' do
          let(:active_duty_end_date) { '07-28-2009' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyEndDate is missing day portion of date' do
          let(:active_duty_end_date) { '2009-07' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeDutyEndDate is not an actual date' do
          let(:active_duty_end_date) { '2023-02-30' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              response_body = JSON.parse(response.body)
              # make sure it is failing for the expected reason, do not need the whole text
              expect(response_body['errors'][0]['detail']).to include(
                'is not a valid date.'
              )
            end
          end
        end

        context 'when the activeDutyEndDate is not present' do
          let(:service_periods) do
            [
              {
                serviceBranch: 'Public Health Service',
                activeDutyBeginDate: '2005-07-28',
                serviceComponent: 'Active',
                separationLocationCode: '98282'
              }
            ]
          end

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the activeBeginDate is not present' do
          let(:service_periods) do
            [
              {
                serviceBranch: 'Public Health Service',
                activeDutyEndDate: 2.days.from_now.strftime('%Y-%m-%d'),
                serviceComponent: 'Active',
                separationLocationCode: '98282'
              }
            ]
          end

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when neither activeDutyEndDate or activeBeginEndDate is present' do
          let(:service_periods) do
            [
              {
                serviceBranch: 'Public Health Service',
                serviceComponent: 'Active',
                separationLocationCode: '98282'
              }
            ]
          end

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when there are more than one service periods' do
          let(:service_periods) do
            [
              {
                serviceBranch: 'Public Health Service',
                serviceComponent: 'Active',
                activeDutyBeginDate: '2008-11-14',
                activeDutyEndDate: '2023-10-30',
                separationLocationCode: '98282'
              },
              {
                serviceBranch: 'Public Health Service',
                serviceComponent: 'Active',
                activeDutyBeginDate: '2008-11-14',
                activeDutyEndDate: '2023-10-30',
                separationLocationCode: '98282'
              }
            ]
          end

          it 'passes vaidation' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when the activeDutyEndDate is in the future' do
          let(:active_duty_end_date) { 2.months.from_now.strftime('%Y-%m-%d') }

          context 'and the separationLocationCode is present' do
            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                  active_duty_end_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end

            context 'and the separationLocationCode is blank' do
              let(:separation_location_code) { nil }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  service_period = json['data']['attributes']['serviceInformation']['servicePeriods'][0]
                  service_period['activeDutyEndDate'] = active_duty_end_date
                  service_period['separationLocationCode'] = separation_location_code
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context 'and the separationLocationCode is an empty string' do
              let(:separation_location_code) { '' }

              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json = JSON.parse(data)
                  service_period = json['data']['attributes']['serviceInformation']['servicePeriods'][0]
                  service_period['activeDutyEndDate'] = active_duty_end_date
                  service_period['separationLocationCode'] = separation_location_code
                  data = json.to_json
                  post submit_path, params: data, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end
        end

        context 'when there are multiple confinements' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2016-12-01'
              },
              {
                approximateBeginDate: '2017-11-01',
                approximateEndDate: '2017-12-01'
              }
            ]
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when there are multiple confinements that overlap' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2017-12-01'
              },
              {
                approximateBeginDate: '2017-11-01',
                approximateEndDate: '2017-12-01'
              }
            ]
          end

          it 'responds with a 422 when the date ranges do overlap' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when there are 3 confinement periods' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2017-12-01'
              },
              {
                approximateBeginDate: '2018-02-01',
                approximateEndDate: '2018-10-01'
              },
              {
                approximateBeginDate: '2018-11-01',
                approximateEndDate: '2018-12-01'
              }
            ]
          end

          it 'responds with a 422 when the date ranges do overlap' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when there are 3 confinement periods that overlap' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2017-12-01'
              },
              {
                approximateBeginDate: '2017-11-01',
                approximateEndDate: '2017-12-01'
              },
              {
                approximateBeginDate: '2018-11-01',
                approximateEndDate: '2018-12-01'
              }
            ]
          end

          it 'responds with a 422 when the date ranges do overlap' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when there are confinements with mixed date formatting and begin date is <= to end date' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2016-12'
              },
              {
                approximateBeginDate: '2017-11-01',
                approximateEndDate: '2018-02'
              }
            ]
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when there are confinements with mixed date formatting and confinement spans one month' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-01',
                approximateEndDate: '2016-11'
              },
              {
                approximateBeginDate: '2017-02',
                approximateEndDate: '2017-02'
              }
            ]
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when there are confinements with mixed date formatting where begin date is after the end date' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-11-02',
                approximateEndDate: '2016-01'
              }
            ]
          end

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = confinements
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when confinements.confinement.approximateBeginDate is formatted incorrectly' do
          let(:approximate_begin_date) { '11-24-2021' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateBeginDate'] = approximate_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when confinements.confinement.approximateEndDate is formatted incorrectly' do
          let(:approximate_end_date) { '11-24-2022' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateEndDate'] = approximate_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when confinements.confinement.approximateBeginDate is after approximateEndDate' do
          let(:approximate_end_date) { '2015-06-05' }
          let(:approximate_begin_date) { '2016-06-05' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateEndDate'] = approximate_end_date
              confinement['approximateBeginDate'] = approximate_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when serviceInformation.confinements.approximateBeginDate is before earliest activeDutyBeginDate' do
          let(:active_duty_begin_date) { '2015-08-05' }
          let(:approximate_begin_date) { '2015-06-05' }
          let(:approximate_end_date) { '2016-06-05' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateEndDate'] = approximate_end_date
              confinement['approximateBeginDate'] = approximate_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when confinement dates are not within one of the service period date ranges' do
          let(:active_duty_begin_date) { '2015-08-05' }
          let(:active_duty_end_date) { '2015-08-09' }
          let(:approximate_begin_date) { '2016-06-05' }
          let(:approximate_end_date) { '2016-06-06' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                active_duty_begin_date
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateEndDate'] = approximate_end_date
              confinement['approximateBeginDate'] = approximate_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when confinement dates ARE within one of the service period date ranges' do
          let(:approximate_begin_date) { '2010-06-05' }
          let(:approximate_end_date) { '2010-06-06' }
          let(:service_period_one) do
            {
              'serviceBranch' => 'Air Force',
              'serviceComponent' => 'Active',
              'activeDutyBeginDate' => '2010-01-05',
              'activeDutyEndDate' => '2010-08-09',
              'separationLocationCode' => '98282'
            }
          end
          let(:service_period_two) do
            {
              'serviceBranch' => 'Air Force',
              'serviceComponent' => 'Active',
              'activeDutyBeginDate' => '2020-01-05',
              'activeDutyEndDate' => '2020-08-09',
              'separationLocationCode' => '98282'
            }
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              # Clear treatments data to avoid false positive 422
              json['data']['attributes']['treatments'] = []
              json['data']['attributes']['serviceInformation']['servicePeriods'][1] = service_period_one
              json['data']['attributes']['serviceInformation']['servicePeriods'][2] = service_period_two
              confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
              confinement['approximateEndDate'] = approximate_end_date
              confinement['approximateBeginDate'] = approximate_begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when confinements are not present in service Information' do
          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['confinements'] = []
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when confinements are present in service Information but missing one of the date periods' do
          context 'approximateBeginDate is present but approximateEndDate is not' do
            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
                confinement['approximateEndDate'] = ''
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'approximateEndDate is present but approximateBeginDate is not' do
            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
                confinement['approximateBeginDate'] = ''
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        describe 'disabilities null values' do
          context "when the 'isRelatedToToxicExposure' is null" do
            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse data
                json['data']['attributes']['disabilities'][0]['isRelatedToToxicExposure'] = nil
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context "when the 'isRelatedToToexposureOrEventOrInjuryxicExposure' is null" do
            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse data
                json['data']['attributes']['disabilities'][0]['exposureOrEventOrInjury'] = nil
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end
      end

      describe "'disabilities' validations" do
        context 'when disabilities.name is not present' do
          it 'responds with 422 bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['disabilities'][0]['name'] = ''
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when disabilities.name contains brackets' do
          it 'returns a successful response' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              disability_name = 'osteoarthritis, right knee with chondromalacia' \
                                ' [previously rated as bilateral chondromalacia, diagnostic code 5010]'
              json['data']['attributes']['disabilities'][0]['name'] = disability_name
              json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = disability_name
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        describe "'disabilities.classificationCode' validations" do
          context "when 'disabilities.classificationCode' is valid" do
            it 'returns a successful response' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context "when 'disabilities.classificationCode' is invalid" do
            it 'responds with a bad request' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['classificationCode'] = '1111'
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context "when 'disabilities.classificationCode' is null" do
            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['classificationCode'] = nil
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end

        describe "'disabilities.ratedDisabilityId' validations" do
          context "when 'disabilities.disabilityActionType' equals 'INCREASE'" do
            context "and 'disabilities.ratedDisabilityId' is not provided" do
              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      diagnosticCode: 123,
                      disabilityActionType: 'INCREASE',
                      serviceRelevance: 'Heavy equipment operator in service.',
                      name: 'PTSD (post traumatic stress disorder)'
                    }
                  ]
                  treatments = [
                    {
                      center: {
                        name: 'Center One',
                        state: 'GA',
                        city: 'Decatur'
                      },
                      treatedDisabilityNames: ['PTSD (post traumatic stress disorder)'],
                      beginDate: '2009-03'
                    }
                  ]
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['treatments'] = treatments
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context "and 'disabilities.ratedDisabilityId' is provided" do
              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      diagnosticCode: 123,
                      ratedDisabilityId: '1100583',
                      disabilityActionType: 'INCREASE',
                      serviceRelevance: 'Heavy equipment operator in service.',
                      name: 'Traumatic Brain Injury',
                      secondaryDisabilities: [
                        {
                          name: 'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders',
                          disabilityActionType: 'SECONDARY',
                          serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                        }
                      ]
                    }
                  ]
                  treatments = [
                    {
                      center: {
                        name: 'Center One',
                        state: 'GA',
                        city: 'Decatur'
                      },
                      treatedDisabilityNames: ['Traumatic Brain Injury'],
                      beginDate: '2009-03'
                    }
                  ]
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['treatments'] = treatments
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context "and 'disabilities.diagnosticCode' is not provided" do
              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      ratedDisabilityId: '1100583',
                      disabilityActionType: 'INCREASE',
                      serviceRelevance: 'Heavy equipment operator in service.',
                      name: 'PTSD (post traumatic stress disorder)'
                    }
                  ]
                  treatments = [
                    {
                      center: {
                        name: 'Center One',
                        state: 'GA',
                        city: 'Decatur'
                      },
                      treatedDisabilityNames: ['PTSD (post traumatic stress disorder)'],
                      beginDate: '2009-03'
                    }
                  ]
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['treatments'] = treatments
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end

          context "when 'disabilities.disabilityActionType' equals 'NONE'" do
            context "and 'disabilities.secondaryDisabilities' is defined" do
              context "and 'disabilities.diagnosticCode is not provided" do
                it 'responds with a 202' do
                  mock_ccg(scopes) do |auth_header|
                    json_data = JSON.parse data
                    params = json_data
                    disabilities = [
                      {
                        disabilityActionType: 'NONE',
                        name: 'PTSD (post traumatic stress disorder)',
                        serviceRelevance: 'Heavy equipment operator in service.',
                        secondaryDisabilities: [
                          {
                            name: 'Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders',
                            disabilityActionType: 'SECONDARY',
                            serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                          }
                        ]
                      }
                    ]
                    treatments = [
                      {
                        center: {
                          name: 'Center One',
                          state: 'GA',
                          city: 'Decatur'
                        },
                        treatedDisabilityNames: ['PTSD (post traumatic stress disorder)'],
                        beginDate: '2009-03'
                      }
                    ]
                    params['data']['attributes']['disabilities'] = disabilities
                    params['data']['attributes']['treatments'] = treatments
                    post submit_path, params: params.to_json, headers: auth_header
                    expect(response).to have_http_status(:accepted)
                  end
                end
              end
            end
          end

          context "when 'disabilities.disabilityActionType' equals value other than 'INCREASE'" do
            context "and 'disabilities.ratedDisabilityId' is not provided" do
              it 'responds with a 202' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'][0]['disabilityActionType'] = 'NEW'
                  params['data']['attributes']['disabilities'][0]['ratedDisabilityId'] = nil
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end
          end
        end

        describe "'disabilities.approximateDate' validations" do
          context "when 'approximateDate' is in the future" do
            let(:approximate_date) { (Time.zone.today + 1.year).strftime('%Y-%m-%d') }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context "when 'approximateDate' is in the past" do
            let(:approximate_date) { (Time.zone.today - 1.year).strftime('%Y-%m-%d') }

            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context 'when approximateDate is formatted YYYY-MM and is in the past' do
            let(:approximate_date) { (Time.zone.today - 6.months).strftime('%Y-%m') }

            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context 'when approximateDate is formatted MM-YYYY and is in the past' do
            let(:approximate_date) { (Time.zone.today - 6.months).strftime('%m-%Y') }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when approximateDate is formatted MM-DD-YYYY and is in the past' do
            let(:approximate_date) { (Time.zone.today - 6.months).strftime('%m-%d-%Y') }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when approximateDate is formatted YYYY-MM and is in the future' do
            let(:approximate_date) { (Time.zone.today + 1.year).strftime('%Y-%m') }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when approximateDate is formatted YYYY' do
            let(:approximate_date) { (Time.zone.today - 1.month).strftime('%Y') }

            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end

          context 'when approximateDate is null' do
            let(:approximate_date) { nil }

            it 'responds with a 202' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end

        # real world example see API-31426
        context 'when approximateDate contains the name of the month as a string' do
          let(:approximate_date) { 'July 2017' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['disabilities'][0]['approximateDate'] = approximate_date
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        describe "'disabilities.serviceRelevance' validations" do
          context "when 'disabilities.disabilityActionType' equals 'NEW'" do
            context "and 'disabilities.serviceRelevance' is not provided" do
              it 'responds with a 422' do
                mock_ccg(scopes) do |auth_header|
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      diagnosticCode: 123,
                      disabilityActionType: 'NEW',
                      serviceRelevance: '',
                      name: 'PTSD (post traumatic stress disorder)'
                    }
                  ]
                  params['data']['attributes']['disabilities'] = disabilities
                  post submit_path, params: params.to_json, headers: auth_header
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end

      describe "'disabilities.secondaryDisabilities' validations" do
        context 'when a secondaryDisability is added' do
          context 'but name is not present' do
            it 'returns a 422' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NONE',
                    name: 'PTSD (post traumatic stress disorder)',
                    serviceRelevance: 'Heavy equipment operator in service.',
                    diagnosticCode: 9999,
                    secondaryDisabilities: [
                      {
                        disabilityActionType: 'SECONDARY',
                        name: '',
                        serviceRelevance: 'Caused by a service-connected disability.',
                        classificationCode: '',
                        approximateDate: '2019'
                      }
                    ]
                  }
                ]
                params['data']['attributes']['disabilities'] = disabilities
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
                response_body = JSON.parse(response.body)
                expect(response_body['errors'].count).to eq(1)
              end
            end
          end

          context 'but disabilityActionType is not present' do
            it 'raises an exception' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'REOPEN',
                    name: 'PTSD (post traumatic stress disorder)',
                    serviceRelevance: 'Heavy equipment operator in service.',
                    diagnosticCode: 9999,
                    secondaryDisabilities: [
                      {
                        name: 'PTSD',
                        serviceRelevance: 'Caused by a service-connected disability.',
                        classificationCode: '',
                        approximateDate: '2019'
                      }
                    ]
                  }
                ]
                params['data']['attributes']['disabilities'] = disabilities
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'but serviceRelevance is not present' do
            it 'raises an exception' do
              mock_ccg(scopes) do |auth_header|
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NEW',
                    name: 'PTSD (post traumatic stress disorder)',
                    diagnosticCode: 9999,
                    secondaryDisabilities: [
                      {
                        disabilityActionType: 'SECONDARY',
                        name: 'PTSD',
                        serviceRelevance: '',
                        classificationCode: '',
                        approximateDate: '2019'
                      }
                    ]
                  }
                ]
                params['data']['attributes']['treatments'] =
                  [{ 'beginDate' => '2009-03', 'treatedDisabilityNames' => ['PTSD (post traumatic stress disorder)'],
                     'center' => { 'name' => 'Center One', 'city' => 'Decatur', 'state' => 'GA' } }]
                params['data']['attributes']['disabilities'] = disabilities
                post submit_path, params: params.to_json, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
                response_body = JSON.parse(response.body)
                expect(response_body['errors'][0]['detail']).to eq(
                  "The serviceRelevance (0) is required if 'disabilityActionType' is NEW."
                )
              end
            end
          end
        end

        context 'when disabilityActionType is NONE with secondaryDisabilities but no diagnosticCode' do
          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.'
                    }
                  ]
                }
              ]
              treatments = [
                {
                  center: {
                    name: 'Center One',
                    state: 'GA',
                    city: 'Decatur'
                  },
                  treatedDisabilityNames: ['PTSD (post traumatic stress disorder)'],
                  beginDate: '2009-03'
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              params['data']['attributes']['treatments'] = treatments
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when secondaryDisability disabilityActionType is something other than SECONDARY' do
          it 'raises an exception' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'NEW',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context "when 'disabilities.secondaryDisabilities.classificationCode' is invalid" do
          it 'raises an exception' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      classificationCode: '2222'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context "when 'disabilities.secondaryDisabilities.classificationCode' does not match name" do
          it 'raises an exception' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      classificationCode: '1111'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context "when 'disabilities.secondaryDisabilities.approximateDate' is present" do
          it 'raises an exception if date is invalid' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      approximateDate: '2019-30-02'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          # real world example see API-31426
          it 'raises an exception if date includes the name of the month' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      approximateDate: 'July 2017'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          it 'returns ok if date is approximate and in the past' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'Traumatic Brain Injury',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      approximateDate: '2019-02'
                    }
                  ]
                }
              ]
              treatments =
                [
                  {
                    'center' => {
                      'name' => 'Center One',
                      'state' => 'GA',
                      'city' => 'Decatur'
                    },
                    'treatedDisabilityNames' => ['Traumatic Brain Injury', 'PTSD'],
                    'beginDate' => '2009-03'
                  }
                ]
              params['data']['attributes']['disabilities'] = disabilities
              params['data']['attributes']['treatments'] = treatments
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end

          it 'returns an exception if date is approximate and in the future' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      approximateDate: "#{Time.zone.now.year + 1}-01"
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          it 'raises an exception if date is not in the past' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD (post traumatic stress disorder)',
                      serviceRelevance: 'Caused by a service-connected disability.',
                      approximateDate: "#{Time.zone.now.year + 1}-01-11"
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          it 'returns 202 if approximateDate is in format YYYY' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data

              disabilities = params['data']['attributes']['disabilities']
              disabilities[0]['approximateDate'] = '2018'
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context "when 'disabilities.secondaryDisabilities.classificationCode' is not present" do
          it 'raises an exception if name is not valid structure' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: 'PTSD_;;',
                      serviceRelevance: 'Caused by a service-connected disability.'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end

          it 'raises an exception if name is longer than 255 characters' do
            mock_ccg(scopes) do |auth_header|
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)',
                  diagnosticCode: 9999,
                  serviceRelevance: 'Heavy equipment operator in service.',
                  secondaryDisabilities: [
                    {
                      disabilityActionType: 'SECONDARY',
                      name: (0...256).map { rand(65..90).chr }.join,
                      serviceRelevance: 'Caused by a service-connected disability.'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post submit_path, params: params.to_json, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe "claimProcessType is 'BDD_PROGRAM'" do
        context 'when activeDutyEndDate is between 90 and 180 days in future' do
          let(:claim_process_type) { 'BDD_PROGRAM' }
          let(:active_duty_end_date) { claim_date + 91.days }

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when activeDutyEndDate is not between 90 and 180 days in future' do
          let(:claim_process_type) { 'BDD_PROGRAM' }
          let(:active_duty_end_date) { claim_date + 81.days }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                active_duty_end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when anticipatedSeparationDate is between 90 and 180 days in future' do
          let(:claim_process_type) { 'BDD_PROGRAM' }
          let(:anticipated_separation_date) { claim_date + 91.days }

          it 'responds with 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              json['data']['attributes']['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
                anticipated_separation_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when anticipatedSeparationDate is not between 90 and 180 days in future' do
          let(:claim_process_type) { 'BDD_PROGRAM' }
          let(:anticipated_separation_date) { claim_date + 81.days }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimProcessType'] = claim_process_type
              json['data']['attributes']['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
                anticipated_separation_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe 'service periods' do
        context 'when obligationTermsOfService is empty' do
          let(:empty_date) { '' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              tos = reserves['obligationTermsOfService']
              tos['beginDate'] = empty_date
              tos['endDate'] = empty_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when obligationTermsOfService beginDate is after endDate' do
          let(:begin_date) { '2022-09-04' }
          let(:end_date) { '2021-09-04' }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              tos = reserves['obligationTermsOfService']
              tos['beginDate'] = begin_date
              tos['endDate'] = end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when obligationTermsOfService beginDate is missing' do
          let(:begin_date) { nil }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              reserves['obligationTermsOfService']['beginDate'] = begin_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when obligationTermsOfService endDate is missing' do
          let(:end_date) { nil }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              reserves['obligationTermsOfService']['endDate'] = end_date
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when federalActivation' do
          context 'is missing anticipatedSeparationDate' do
            let(:anticipated_separation_date) { '' }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']
                reserves['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when anticipatedSeparationDate is not in the future' do
            let(:anticipated_separation_date) { 1.month.ago.strftime('%Y-%m-%d') }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']
                reserves['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'is missing activationDate' do
            let(:title_10_activation_date) { '' }

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                reserves = json['data']['attributes']['serviceInformation']
                reserves['federalActivation']['activationDate'] = title_10_activation_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          context 'when activationDate is not after the earliest servicePeriod.activeDutyBeginDate' do
            let(:title_10_activation_date) { '1994-05-05' }
            let(:service_periods) do
              [
                {
                  serviceBranch: 'Public Health Service',
                  activeDutyBeginDate: '1995-02-05',
                  activeDutyEndDate: '1999-01-02',
                  serviceComponent: 'Reserves',
                  separationLocationCode: 'ABCDEFGHIJKLMN'
                },
                {
                  serviceBranch: 'Public Health Service',
                  activeDutyBeginDate: '2006-05-02',
                  activeDutyEndDate: '2016-02-01',
                  serviceComponent: 'Active',
                  separationLocationCode: 'OPQRSTUVWXYZ'
                }
              ]
            end

            it 'responds with a 422' do
              mock_ccg(scopes) do |auth_header|
                json = JSON.parse(data)
                service_information = json['data']['attributes']['serviceInformation']
                service_information['servicePeriods'] = service_periods
                service_information['federalActivation']['activationDate'] =
                  title_10_activation_date
                data = json.to_json
                post submit_path, params: data, headers: auth_header
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context 'when unitPhone.areaCode has non-digits included' do
          let(:area_code) { '89X' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              reserves['unitPhone']['areaCode'] = area_code
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when unitPhone.areaCode has wrong number of digits' do
          let(:area_code) { '1989' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              reserves['unitPhone']['areaCode'] = area_code
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when unitPhone.phoneNumber has wrong number of digits' do
          let(:phone_number) { '123456790123456798012345' }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              reserves = json['data']['attributes']['serviceInformation']['reservesNationalGuardService']
              reserves['unitPhone']['phoneNumber'] = phone_number
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when alternate names are duplicated' do
          let(:alternate_names) { %w[John Johnathan John] }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['alternateNames'] = alternate_names
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when alternate names are duplicated with different cases' do
          let(:alternate_names) { %w[John Johnathan john] }

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['serviceInformation']['alternateNames'] = alternate_names
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      describe 'Validation of direct deposit elements' do
        context 'when direct deposit information does not include the account type' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '123123123123',
              routingNumber: '123123123',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when direct deposit information does not include a valid account type' do
          let(:direct_deposit) do
            {
              accountType: 'Personal',
              accountNumber: '123123123123',
              routingNumber: '123123123',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when direct deposit information does not include the account number' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '',
              routingNumber: '123123123',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when direct deposit information does not include the routing number' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '123123123123',
              routingNumber: '',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when direct deposit information does not include a valid routing number' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '123123123123',
              routingNumber: '12345678-1011121314',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when direct deposit information includes a long account number and financial institution name' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '123123123123888888-888888',
              routingNumber: '123123123',
              financialInstitutionName: 'Long financial institution name example test longer than 35 characters',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        context 'when direct deposit information includes a nil account type' do
          let(:direct_deposit) do
            {
              accountType: nil,
              accountNumber: '123123123123',
              routingNumber: '1234567891011121314',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'if no account is selected but an account type is entered' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '',
              routingNumber: '',
              financialInstitutionName: '',
              noAccount: true
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'if no account is selected but an account number is entered' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '123123123123',
              routingNumber: '',
              financialInstitutionName: '',
              noAccount: true
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'if no account is selected but a routing number is entered' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '',
              routingNumber: '123123123',
              financialInstitutionName: '',
              noAccount: true
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'if no account is selected but a financial institution name is entered' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '',
              routingNumber: '',
              financialInstitutionName: 'Global Bank',
              noAccount: true
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'if no account is selected and no other values are entered' do
          let(:direct_deposit) do
            {
              accountType: nil,
              accountNumber: '',
              routingNumber: '',
              financialInstitutionName: '',
              noAccount: true
            }
          end

          it 'returns a 202' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse data
              json['data']['attributes']['directDeposit'] = direct_deposit
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end
      end

      describe 'Service returns resource not found' do
        context 'when no ICN value is supplied' do
          let(:veteran_id) { nil }

          it 'responds with bad request' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              data = json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:not_found)
            end
          end
        end
      end

      describe 'Overflow Text' do
        context 'when overflow text is not provided' do
          it 'responds with accepted' do
            mock_ccg(scopes) do |auth_header|
              json = JSON.parse(data)
              json['data']['attributes']['claimNotes'] = nil
              data = json.to_json
              post submit_path, params: data, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end
      end
    end

    context 'validate endpoint' do
      let(:veteran_id) { '1012832025V743496' }
      let(:validation_path) { "/services/claims/v2/veterans/#{veteran_id}/526/validate" }

      it 'returns a successful response when valid' do
        mock_ccg(scopes) do |auth_header|
          post validation_path, params: data, headers: auth_header
          expect(response).to have_http_status(:ok)
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_auto_established_claim_validation')
          expect(parsed['data']['attributes']['status']).to eq('valid')
        end
      end
    end

    describe 'attachments', skip: 'Disabling tests for deactivated /veterans/{veteranId}/526/{id}/attachments' do
      context 'attachments' do
        let(:auto_claim) { create(:auto_established_claim) }
        let(:attachments_path) do
          "/services/claims/v2/veterans/#{veteran_id}/526/#{auto_claim.id}/attachments"
        end
        let(:target_veteran) do
          OpenStruct.new(
            icn: veteran_id,
            first_name: 'abraham',
            last_name: 'lincoln',
            loa: { current: 3, highest: 3 },
            ssn: '796111863',
            edipi: '8040545646',
            participant_id: '600061742',
            mpi: OpenStruct.new(
              icn: veteran_id,
              profile: OpenStruct.new(ssn: '796111863')
            )
          )
        end

        describe 'with binary params' do
          let(:binary_params) do
            { attachment1: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                          .split('/')).to_s),
              attachment2: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                          .split('/')).to_s) }
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post attachments_path, params: binary_params, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        describe 'with base 64 params' do
          let(:base64_params) do
            { attachment1: File.read(Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s),
              attachment2: File.read(Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s) }
          end

          it 'responds with a 202' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post attachments_path, params: base64_params, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end
        end

        describe 'with more then 10 attachments' do
          let(:binary_params) do
            { attachment1: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment2: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment3: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment4: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment5: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment7: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment6: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment8: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment9: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment10: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s),
              attachment11: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
              .split('/')).to_s) }
          end

          it 'responds with a 422' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post attachments_path, params: binary_params, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end
    end

    describe '#generate_pdf' do
      let(:invalid_scopes) { %w[claim.write claim.read] }
      let(:generate_pdf_scopes) { %w[system/526-pdf.override] }
      let(:generate_pdf_path) { "/services/claims/v2/veterans/#{veteran_id}/526/generatePDF/minimum-validations" }

      context 'valid data' do
        it 'responds with a 200' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response.header['Content-Disposition']).to include('filename')
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'invalid scopes' do
        it 'returns a 401 unauthorized' do
          mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context 'without the first and last name present' do
        it 'does not allow the generatePDF call to occur' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            target_veteran.first_name = ''
            target_veteran.last_name = ''
            allow_any_instance_of(ClaimsApi::V2::ApplicationController)
              .to receive(:target_veteran).and_return(target_veteran)

            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.parsed_body['errors'][0]['detail']).to eq('Must have either first or last name')
          end
        end
      end

      context 'without the first name present' do
        it 'allows the generatePDF call to occur' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            target_veteran.first_name = ''
            allow_any_instance_of(ClaimsApi::V2::ApplicationController)
              .to receive(:target_veteran).and_return(target_veteran)

            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'when the PDF string is not generated' do
        it 'returns a 422 response when empty object is returned' do
          allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
            .to receive(:generate_526_pdf)
            .and_return({})

          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        it 'returns a 422 response if nil gets returned' do
          allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
            .to receive(:generate_526_pdf)
            .and_return(nil)

          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end

  describe 'POST #submit not using md5 lookup',
           skip: 'Disabling tests for deactivated /veterans/{veteranId}/526 endpoint' do
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:veteran_id) { '1013062086V794840' }
    let(:submit_path) { "/services/claims/v2/veterans/#{veteran_id}/526" }

    it 'creates a new claim if duplicate submit occurs (does not use md5 lookup)' do
      mock_ccg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/disability_comp') do
          json = JSON.parse(data)
          post submit_path, params: json.to_json, headers: auth_header
          expect(response).to have_http_status(:accepted)
          first_submit_parsed = JSON.parse(response.body)
          @original_id = first_submit_parsed['data']['id']
        end
      end
      mock_ccg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/disability_comp') do
          json = JSON.parse(data)
          post submit_path, params: json.to_json, headers: auth_header
          expect(response).to have_http_status(:accepted)
          duplicate_submit_parsed = JSON.parse(response.body)
          duplicate_id = duplicate_submit_parsed['data']['id']
          expect(@original_id).not_to eq(duplicate_id)
        end
      end
    end
  end

  describe 'POST #synchronous' do
    let(:veteran_id) { '1012832025V743496' }
    let(:synchronous_path) { "/services/claims/v2/veterans/#{veteran_id}/526/synchronous" }
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:synchronous_scopes) { %w[system/526.override system/claim.write] }
    let(:invalid_scopes) { %w[system/526-pdf.override] }
    let(:meta) do
      { transactionId: '00000000-0000-0000-000000000000' }
    end

    context 'submission to synchronous' do
      context 'with a transaction_id' do
        context 'present' do
          it 'saves the transaction ID on the claim record' do
            mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
              VCR.use_cassette('claims_api/disability_comp') do
                json = JSON.parse data
                json['meta'] = meta
                data = json.to_json
                post synchronous_path, params: data, headers: auth_header

                parsed_res = JSON.parse(response.body)
                claim_id = parsed_res['data']['id']
                aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)

                expect(aec.transaction_id).to eq(meta[:transactionId])
                expect(parsed_res['meta']['transactionId']).to eq(meta[:transactionId])
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end

        context 'absent' do
          it 'has a null transaction ID on the claim record' do
            mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
              VCR.use_cassette('claims_api/disability_comp') do
                post synchronous_path, params: data, headers: auth_header

                parsed_res = JSON.parse(response.body)
                claim_id = parsed_res['data']['id']
                aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)

                expect(aec.transaction_id).to be_nil
                expect(parsed_res).not_to have_key('meta')
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end
      end

      it 'returns an empty test object' do
        mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
          VCR.use_cassette('claims_api/disability_comp') do
            post synchronous_path, params: data, headers: auth_header

            parsed_res = JSON.parse(response.body)
            expect(parsed_res['data']['attributes']).to include('claimId')
          end
        end
      end

      it 'returns a 202 response when successful' do
        mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
          VCR.use_cassette('claims_api/disability_comp') do
            post synchronous_path, params: data, headers: auth_header

            expect(response).to have_http_status(:accepted)
          end
        end
      end

      it 'returns a 401 unauthorized with incorrect scopes' do
        mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
          post synchronous_path, params: data, headers: auth_header

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it 'returns a 202 when the s3 upload is mocked' do
        with_settings(Settings.claims_api.benefits_documents, use_mocks: true) do
          mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
            VCR.use_cassette('claims_api/disability_comp') do
              post synchronous_path, params: data, headers: auth_header

              expect(response).to have_http_status(:accepted)
            end
          end
        end
      end
    end

    context 'handling for missing first and last name' do
      context 'without the first and last name present' do
        it 'does not allow the submit to occur' do
          mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
            VCR.use_cassette('claims_api/disability_comp') do
              target_veteran.first_name = ''
              target_veteran.last_name = ''
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post synchronous_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq('Missing first and last name')
            end
          end
        end
      end
    end
  end
end
