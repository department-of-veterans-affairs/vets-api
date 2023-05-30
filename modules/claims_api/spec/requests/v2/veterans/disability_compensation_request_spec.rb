# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write claim.read] }
  let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }

  before do
    stub_poa_verification
    stub_mpi
    Timecop.freeze(Time.zone.now)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    context 'submit' do
      let(:claim_date) { (Time.zone.today - 1.day).to_s }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                               'form_526_json_api.json').read
        temp = JSON.parse(temp)
        temp['data']['attributes']['claimDate'] = claim_date

        temp.to_json
      end
      let(:veteran_id) { '1012667145V762142' }
      let(:path) { "/services/claims/v2/veterans/#{veteran_id}/526" }
      let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
      let(:parsed_codes) do
        {
          birls_id: '111985523',
          participant_id: '32397028'
        }
      end
      let(:add_response) { build(:add_person_response, parsed_codes:) }

      # real world example happened in API-15575
      describe "'claim_date' difference between Lighthouse (UTC) and EVSS (Central Time)" do
        context 'when UTC is currently a day ahead of the US Central Time Zone' do
          before do
            Timecop.freeze(Time.parse('2022-05-01 04:46:31 UTC'))
          end

          after do
            Timecop.return
          end

          context "and 'claim_date' is same as the Central Time Zone day" do
            let(:claim_date) { (Time.zone.today - 1.day).to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' is earlier than the Central Time Zone day" do
            let(:claim_date) { (Time.zone.today - 7.days).to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' is later than both the Central Time Zone day and UTC day" do
            let(:claim_date) { (Time.zone.today + 7.days).to_s }

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end

        context 'when UTC is same day as the US Central Time Zone day' do
          before do
            Timecop.freeze(Time.parse('2023-05-01 12:00:00 UTC'))
          end

          after do
            Timecop.return
          end

          context "and 'claim_date' is the current day" do
            let(:claim_date) { Time.zone.today.to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' is in the past" do
            let(:claim_date) { (Time.zone.today - 1.day).to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' is in the future" do
            let(:claim_date) { (Time.zone.today + 7.days).to_s }

            it 'responds with bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end

          context "and 'claim_date' has timezone (iso w/Z)" do
            let(:claim_date) { 1.day.ago.iso8601 }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' has timezone (iso wo/Z)" do
            let(:claim_date) { 1.day.ago.iso8601.sub('Z', '-00:00') }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context "and 'claim_date' has timezone (iso w/out zone)" do
            let(:claim_date) { 1.day.ago.iso8601.sub('Z', '') }

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "and 'claim_date' has timezone (TZ String)" do
            let(:claim_date) { 1.day.ago.to_s }

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "and 'claim_date' has timezone (w/out T)" do
            let(:claim_date) { 1.day.ago.iso8601.sub('T', ' ') }

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "and 'claim_date' improperly formatted (hello world)" do
            let(:claim_date) { 'hello world' }

            it 'responds with bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "and 'claim_date' improperly formatted (empty string)" do
            let(:claim_date) { '' }

            it 'responds with bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end

      describe 'schema catches claimProcessType error' do
        context 'when something other than an enum option is used' do
          let(:claim_process_type) { 'claim_test' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                json = JSON.parse(data)
                json['data']['attributes']['claimProcessType'] = claim_process_type
                data = json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context 'when an empty string is provided' do
          let(:claim_process_type) { ' ' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                json = JSON.parse(data)
                json['data']['attributes']['claimProcessType'] = claim_process_type
                data = json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      describe 'validation of claimant certification' do
        context 'when the cert is false' do
          let(:claimant_certification) { false }

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                json = JSON.parse(data)
                json['data']['attributes']['claimantCertification'] = claimant_certification
                data = json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      describe 'validation of claimant mailing address elements' do
        context 'when the country is valid' do
          let(:country) { 'USA' }

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['veteranIdentification']['mailingAddress']['country'] = country
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context 'when the country is invalid' do
          let(:country) { 'United States of Nada' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['veteranIdentification']['mailingAddress']['country'] = country
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end

        context 'when no mailing address data is found' do
          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['veteranIdentification']['mailingAddress'] = {}
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end

      context 'when the phone has non-digits included' do
        let(:telephone) { '123456789X' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['veteranNumber']['telephone'] = telephone
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the internationalTelephone has non-digits included' do
        let(:international_telephone) { '123456789X' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['veteranNumber']['internationalTelephone'] =
                  international_telephone
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the zipFirstFive has non-digits included' do
        let(:zip_first_five) { '1234X' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['zipFirstFive'] = zip_first_five
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the zipLastFour has non-digits included' do
        let(:zip_last_four) { '123X' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['zipLastFour'] = zip_last_four
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the apartmentOrUnitNumber exceeds the max length' do
        let(:apartment_or_unit_number) { '123456' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['apartmentOrUnitNumber'] =
                  apartment_or_unit_number
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the numberAndStreet exceeds the max length' do
        let(:number_and_street) { '1234567890abcdefghijklmnopqrstuvwxyz' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['numberAndStreet'] =
                  number_and_street
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the city exceeds the max length' do
        let(:city) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['city'] = city
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the state has non-alphabetic characters' do
        let(:state) { '!@#$%^&*()_+-=' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['mailingAddress']['state'] = state
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the vaFileNumber exceeds the max length' do
        let(:va_file_number) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['vaFileNumber'] = va_file_number
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when currentlyVaEmployee is a non-boolean value' do
        let(:currently_va_employee) { 'negative' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['currentlyVaEmployee'] =
                  currently_va_employee
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when serviceNumber exceeds max length' do
        let(:service_number) { '1234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['serviceNumber'] = service_number
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when email exceeds max length' do
        let(:email) { '1234567890abcdefghijklmnopqrstuvwxyz@someinordiantelylongdomain.com' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['emailAddress'] = email
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when email is not valid' do
        let(:email) { '.invalid@somedomain.com' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['emailAddress'] = email
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when agreeToEmailRelatedToClaim is a non-boolean value' do
        let(:agree_to_email_related_to_claim) { 'negative' }

        it 'responds with bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['veteranIdentification']['emailAddress']['agreeToEmailRelatedToClaim'] =
                  agree_to_email_related_to_claim
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      describe 'Validation of claimant homeless elements' do
        context "when 'currentlyHomeless' and 'riskOfBecomingHomeless' are both provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['homeless']['currentlyHomeless'] = {
                    homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                    otherDescription: 'community help center'
                  }
                  params['data']['attributes']['homeless']['riskOfBecomingHomeless'] = {
                    livingSituationOptions: 'losingHousing',
                    otherDescription: 'community help center'
                  }
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'].length).to eq(1)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "Must define only one of 'homeless.currentlyHomeless' or " \
                    "'homeless.riskOfBecomingHomeless'"
                  )
                end
              end
            end
          end
        end
      end

      context "when neither 'currentlyHomeless' nor 'riskOfBecomingHomeless' is provided" do
        context "when 'pointOfContact' is provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['homeless'] = {}
                  params['data']['attributes']['homeless'] = {
                    pointOfContact: 'Jane Doe',
                    pointOfContactNumber: {
                      telephone: '1234567890'
                    }
                  }
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'].length).to eq(1)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If 'homeless.pointOfContact' is defined, then one of " \
                    "'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless'" \
                    ' is required'
                  )
                end
              end
            end
          end
        end

        context "when 'pointOfContact' is not provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['homeless']['currentlyHomeless'] = {
                  homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                  otherDescription: 'community help center'
                }
                params['data']['attributes']['homeless'].delete('pointOfContact')
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
                response_body = JSON.parse(response.body)
                expect(response_body['errors'].length).to eq(1)
                expect(response_body['errors'][0]['detail']).to eq(
                  "If one of 'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is" \
                  " defined, then 'homeless.pointOfContact' is required"
                )
              end
            end
          end
        end
      end

      context "when either 'currentlyHomeless' or 'riskOfBecomingHomeless' is provided" do
        context "when 'pointOfContactNumber' 'telephone' contains alphabetic characters" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['homeless']['currentlyHomeless'] = {
                  homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                  otherDescription: 'community help center'
                }
                params['data']['attributes']['homeless']['pointOfContactNumber']['telephone'] = 'xxxyyyzzzz'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "when 'pointOfContactNumber' 'internationalTelephone' contains alphabetic characters" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['homeless']['currentlyHomeless'] = {
                  homelessSituationOptions: 'FLEEING_CURRENT_RESIDENCE',
                  otherDescription: 'community help center'
                }
                params['data']['attributes']['homeless']['pointOfContactNumber']['intnernationalTelephone'] =
                  'xxxyyyzzzz'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      # toxic exposure validation tests
      context 'when the other_locations_served does not match the regex' do
        let(:other_locations_served) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

        it 'responds with a bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['toxicExposure']['herbicideHazardService']['otherLocationsServed'] =
                  other_locations_served
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the additional_exposures does not match the regex' do
        let(:additional_exposures) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

        it 'responds with a bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['toxicExposure']['additionalHazardExposures']['additionalExposures'] =
                  additional_exposures
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the specify_other_exposures does not match the regex' do
        let(:specify_other_exposures) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

        it 'responds with a bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['toxicExposure']['additionalHazardExposures']['specifyOtherExposures'] =
                  specify_other_exposures
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the exposure_location does not match the regex' do
        let(:exposure_location) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

        it 'responds with a bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['toxicExposure']['multipleExposures']['exposureLocation'] =
                  exposure_location
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      context 'when the hazard_exposed_to does not match the regex' do
        let(:hazard_exposed_to) { 'some !@#@#$#%$^%$#&$^%&&(*978078)' }

        it 'responds with a bad request' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['toxicExposure']['multipleExposures']['hazardExposedTo'] =
                  hazard_exposed_to
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end

      describe 'Validation of treament elements' do
        context 'when treatment startDate is included and in the correct pattern' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context 'when treatment startDate is in the wrong pattern' do
          let(:treatment_start_date) { '12/01/1999' }

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['treatments'][0]['startDate'] = treatment_start_date
                  json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] =
                    '1981-11-15'
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "when 'treatment.startDate' is not included" do
          let(:treatments) do
            [
              {
                center: {
                  name: 'Center One',
                  state: 'GA',
                  city: 'Decatur'
                },
                treatedDisabilityNames: ['PTSD (post traumatic stress disorder)', 'Trauma']
              }
            ]
          end

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse data
                  json['data']['attributes']['treatments'] = treatments
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context 'when treatedDisabilityName includes a name that is not in the list of declared disabilities' do
          let(:not_treated_disability_name) { 'not included in submitted disabilities collection' }

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = not_treated_disability_name
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context 'when treatedDisabilityName includes a name that is declared only as a secondary disability' do
          let(:treated_disability_name) { 'Secondary' }
          let(:secondary_disability_name) { 'Secondary' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json = JSON.parse(data)
                attrs = json['data']['attributes']
                attrs['disabilities'][0]['secondaryDisabilities'][0]['name'] = secondary_disability_name
                attrs['treatments'][0]['treatedDisabilityNames'][0] = treated_disability_name
                data = json.to_json
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end

        context 'when treatedDisabilityName has a match the list of declared disabilities' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end

          context 'but has leading whitespace' do
            let(:treated_disability_name) { '   PTSD (post traumatic stress disorder)' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = treated_disability_name
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'but has trailing whitespace' do
            let(:treated_disability_name) { 'PTSD (post traumatic stress disorder)   ' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = treated_disability_name
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'but has different casing' do
            let(:treated_disability_name) { 'PtSd (PoSt TrAuMaTiC StReSs DiSoRdEr)' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = treated_disability_name
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        context 'validating treatment.centers' do
          context 'when the treatments.center.name' do
            context 'is missing' do
              let(:treated_center_name) { nil }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context 'is a single space' do
              let(:treated_center_name) { ' ' }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context 'has invalid characters in it' do
              let(:treated_center_name) { 'Center//// this $' }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context 'has more then 100 characters in it' do
              let(:treated_center_name) { (0...102).map { ('a'..'z').to_a[rand(26)] }.join }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      json['data']['attributes']['treatments'][0]['center']['name'] = treated_center_name
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context 'is a valid string of characters' do
              it 'returns a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end
          end

          context 'when the treatments.center.city' do
            context 'is a valid string of characters' do
              it 'returns a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end

            context 'has invalid characters in it' do
              let(:treated_center_city) { 'LMNOP 6' }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse data
                      json['data']['attributes']['treatments'][0]['center']['city'] = treated_center_city
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end
          end

          context 'when the treatments.center.state' do
            context 'is in the correct 2 letter format' do
              it 'returns a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end

            context 'is not in the correct 2 letter format' do
              let(:treated_center_state) { 'LMNOP' }

              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse data
                      json['data']['attributes']['treatments'][0]['center']['state'] = treated_center_state
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end
          end
        end
      end

      describe 'Validation of service information elements' do
        context 'when the serviceBranch is empty' do
          let(:service_branch) { '' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['servicePeriods'][0]['serviceBranch'] =
                    service_branch
                  data = json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the activeDutyBeginDate is after the activeDutyEndDate' do
          let(:active_duty_end_date) { '1979-01-02' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                    active_duty_end_date
                  data = json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the activeDutyBeginDate is not formatted correctly' do
          let(:active_duty_begin_date) { '25-06-1979' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                    active_duty_begin_date
                  data = json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the activeDutyEndDate is not formatted correctly' do
          let(:active_duty_end_date) { '28-07-1995' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                    active_duty_end_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the activeDutyEndDate is in the future' do
          let(:active_duty_end_date) { 2.months.from_now.strftime('%Y-%m-%d') }

          context 'and the seperationLocationCode is present' do
            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                      active_duty_end_date
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end

            context 'and the seperationLocationCode is blank' do
              let(:separation_location_code) { nil }

              it 'responds with a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      service_period = json['data']['attributes']['serviceInformation']['servicePeriods'][0]
                      service_period['activeDutyEndDate'] = active_duty_end_date
                      service_period['separationLocationCode'] = separation_location_code
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context 'and the seperationLocationCode is an empty string' do
              let(:separation_location_code) { '' }

              it 'responds with a 422' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json = JSON.parse(data)
                      service_period = json['data']['attributes']['serviceInformation']['servicePeriods'][0]
                      service_period['activeDutyEndDate'] = active_duty_end_date
                      service_period['separationLocationCode'] = separation_location_code
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end
          end
        end

        context 'when there are mutiple confinements' do
          let(:confinements) do
            [
              {
                approximateBeginDate: '2016-01-01',
                approximateEndDate: '2016-01-06'
              },
              {
                approximateBeginDate: '2017-01-01',
                approximateEndDate: '2017-01-06'
              }
            ]
          end

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['confinements'] = confinements
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context 'when confinements.confinement.approximateBeginDate is formatted incorrectly' do
          let(:approximate_begin_date) { '11-24-2021' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
                  confinement['approximateBeginDate'] = approximate_begin_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when confinements.confinement.approximateEndDate is formatted incorrectly' do
          let(:approximate_end_date) { '11-24-2022' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
                  confinement['approximateEndDate'] = approximate_end_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when confinements.confinement.approximateBeginDate is after approximateEndDate' do
          let(:approximate_end_date) { '2017-05-06' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  confinement = json['data']['attributes']['serviceInformation']['confinements'][0]
                  confinement['approximateEndDate'] = approximate_end_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end
    end

    context 'validate' do
    end

    context 'attachments' do
    end
  end
end
