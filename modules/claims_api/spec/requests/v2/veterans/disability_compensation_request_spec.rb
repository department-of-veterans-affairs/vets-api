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
    Timecop.freeze(Time.zone.now)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    context 'submit' do
      let(:claim_date) { (Time.zone.today - 1.day).to_s }
      let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                               'form_526_json_api.json').read
        temp = JSON.parse(temp)
        temp['data']['attributes']['claimDate'] = claim_date
        temp['data']['attributes']['serviceInformation']['reservesNationalGuardService']['title10Activation']['anticipatedSeparationDate'] = # rubocop:disable Layout/LineLength
          anticipated_separation_date

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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                    VCR.use_cassette('brd/disabilities') do
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
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
                  VCR.use_cassette('brd/disabilities') do
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

      describe 'validation of claimant change of address elements' do
        context 'when the country is valid' do
          let(:country) { 'USA' }

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse(data)
                    json['data']['attributes']['changeOfAddress']['country'] = country
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
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
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse(data)
                    json['data']['attributes']['changeOfAddress']['country'] = country
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:bad_request)
                  end
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
                  json['data']['attributes']['changeOfAddress'] = {}
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when the begin date is after the end date' do
          let(:begin_date) { '2023-01-01' }
          let(:end_date) { '2022-01-01' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse(data)
                    json['data']['attributes']['changeOfAddress']['dates']['beginningDate'] = begin_date
                    json['data']['attributes']['changeOfAddress']['dates']['endingDate'] = end_date
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end
        end
      end

      context 'when the phone has non-digits included' do
        let(:telephone) { '123456789X' }

        it 'responds with unprocessable request' do
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
                  VCR.use_cassette('brd/disabilities') do
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
      end

      context "when neither 'currentlyHomeless' nor 'riskOfBecomingHomeless' is provided" do
        context "when 'pointOfContact' is provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
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
        end

        context "when 'pointOfContact' is not provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
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
                let(:receiving) { true }
                let(:future) { true }

                it 'responds with a bad request' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('evss/claims/claims') do
                      VCR.use_cassette('brd/countries') do
                        VCR.use_cassette('brd/disabilities') do
                          json_data = JSON.parse data
                          params = json_data
                          params['data']['attributes']['servicePay'] = service_pay_attribute
                          post path, params: params.to_json, headers: headers.merge(auth_header)
                          expect(response).to have_http_status(:bad_request)
                        end
                      end
                    end
                  end
                end
              end

              context "when both are 'false'" do
                let(:receiving) { false }
                let(:future) { false }

                it 'responds with a bad request' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        json_data = JSON.parse data
                        params = json_data
                        params['data']['attributes']['servicePay'] = service_pay_attribute
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:bad_request)
                      end
                    end
                  end
                end
              end
            end

            context "when 'receivingMilitaryRetiredPay' and 'futureMilitaryRetiredPay' are not equal" do
              context "when 'receivingMilitaryRetiredPay' is 'false' and 'futureMilitaryRetiredPay' is 'true'" do
                let(:receiving) { false }
                let(:future) { true }

                it 'responds with a 200' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('evss/claims/claims') do
                      VCR.use_cassette('brd/countries') do
                        VCR.use_cassette('brd/disabilities') do
                          json_data = JSON.parse data
                          params = json_data
                          params['data']['attributes']['servicePay'] = service_pay_attribute
                          post path, params: params.to_json, headers: headers.merge(auth_header)
                          expect(response).to have_http_status(:ok)
                        end
                      end
                    end
                  end
                end
              end

              context "when 'receivingMilitaryRetiredPay' is 'true' and 'futureMilitaryRetiredPay' is 'false'" do
                let(:receiving) { true }
                let(:future) { false }

                it 'responds with a 200' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('evss/claims/claims') do
                      VCR.use_cassette('brd/countries') do
                        VCR.use_cassette('brd/disabilities') do
                          json_data = JSON.parse data
                          params = json_data
                          params['data']['attributes']['servicePay'] = service_pay_attribute
                          post path, params: params.to_json, headers: headers.merge(auth_header)
                          expect(response).to have_http_status(:ok)
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          describe "'payment'" do
            let(:service_pay_attribute) do
              {
                receivingMilitaryRetiredPay: true,
                futureMilitaryRetiredPay: false,
                militaryRetiredPay: {
                  branchOfService: 'Air Force',
                  monthlyAmount: military_retired_payment_amount
                }
              }
            end

            context "when 'monthlyAmount' is below the minimum" do
              let(:military_retired_payment_amount) { 0 }

              it 'responds with an unprocessible entity' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end

            context "when 'monthlyAmount' is above the maximum" do
              let(:military_retired_payment_amount) { 1_000_000 }

              it 'responds with an unprocessible entity' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context "when 'monthlyAmount' is within limits" do
              let(:military_retired_payment_amount) { 100 }

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        json_data = JSON.parse data
                        params = json_data
                        params['data']['attributes']['servicePay'] = service_pay_attribute
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end
              end
            end
          end

          describe "'futurePayExplanation'" do
            context "when 'futureMilitaryRetiredPay' is 'true'" do
              let(:future_military_retired_pay) { true }

              context "when 'futureMilitaryRetiredPayExplanation' is not provided" do
                let(:service_pay_attribute) do
                  {
                    receivingMilitaryRetiredPay: false,
                    futureMilitaryRetiredPay: future_military_retired_pay,
                    militaryRetiredPay: {
                      branchOfService: 'Air Force'
                    }
                  }
                end

                it 'responds with an unprocessible entity' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        json_data = JSON.parse data
                        params = json_data
                        params['data']['attributes']['servicePay'] = service_pay_attribute
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:unprocessable_entity)
                      end
                    end
                  end
                end
              end

              context "when 'futureMilitaryRetiredPayExplanation' is provided" do
                let(:service_pay_attribute) do
                  {
                    receivingMilitaryRetiredPay: false,
                    futureMilitaryRetiredPay: future_military_retired_pay,
                    futureMilitaryRetiredPayExplanation: 'Retiring soon.',
                    militaryRetiredPay: {
                      branchOfService: 'Air Force'
                    }
                  }
                end

                it 'responds with a 200' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('evss/claims/claims') do
                      VCR.use_cassette('brd/countries') do
                        VCR.use_cassette('brd/disabilities') do
                          json_data = JSON.parse data
                          params = json_data
                          params['data']['attributes']['servicePay'] = service_pay_attribute
                          post path, params: params.to_json, headers: headers.merge(auth_header)
                          expect(response).to have_http_status(:ok)
                        end
                      end
                    end
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
                receivedSeparationOrSeverancePay: true,
                separationSeverancePay: {
                  datePaymentReceived: (Time.zone.today - 1.year).to_s,
                  branchOfService: 'Air Force',
                  preTaxAmountReceived: separation_payment_amount
                }
              }
            end

            context "when 'preTaxAmountReceived' is below the minimum" do
              let(:separation_payment_amount) { 0 }

              it 'responds with an unprocessible entity' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end

            context "when 'preTaxAmountReceived' is above the maximum" do
              let(:separation_payment_amount) { 1_000_000 }

              it 'responds with an unprocessible entity' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context "when 'preTaxAmountReceived' is within limits" do
              let(:separation_payment_amount) { 100 }

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        json_data = JSON.parse data
                        params = json_data
                        params['data']['attributes']['servicePay'] = service_pay_attribute
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end
              end
            end
          end

          describe "'datePaymentReceived'" do
            let(:service_pay_attribute) do
              {
                receivedSeparationOrSeverancePay: true,
                separationSeverancePay: {
                  datePaymentReceived: received_date,
                  branchOfService: 'Air Force',
                  preTaxAmountReceived: 100
                }
              }
            end

            context "when 'datePaymentReceived' is not in the past" do
              let(:received_date) { (Time.zone.today + 1.day).to_s }

              it 'responds with a bad request' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end

            context "when 'datePaymentReceived' is in the past" do
              let(:received_date) { (Time.zone.today - 1.year).to_s }

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        json_data = JSON.parse data
                        params = json_data
                        params['data']['attributes']['servicePay'] = service_pay_attribute
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end
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
                  VCR.use_cassette('brd/disabilities') do
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
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
                treatedDisabilityNames: ['PTSD (post traumatic stress disorder)', 'Traumatic Brain Injury']
              }
            ]
          end

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
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
        end

        context 'when treatedDisabilityName includes a name that is not in the list of declared disabilities' do
          let(:not_treated_disability_name) { 'not included in submitted disabilities collection' }

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
                  json = JSON.parse(data)
                  json['data']['attributes']['treatments'][0]['treatedDisabilityNames'][0] = not_treated_disability_name
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when treatedDisabilityName includes a name that is declared only as a secondary disability' do
          let(:treated_disability_name) { 'Cancer - Musculoskeletal - Elbow' }
          let(:secondary_disability_name) { 'Cancer - Musculoskeletal - Elbow' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
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
        end

        context 'when treatedDisabilityName has a match the list of declared disabilities' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end

          context 'but has leading whitespace' do
            let(:treated_disability_name) { '   PTSD (post traumatic stress disorder)' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
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

          context 'but has trailing whitespace' do
            let(:treated_disability_name) { 'PTSD (post traumatic stress disorder)   ' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
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

          context 'but has different casing' do
            let(:treated_disability_name) { 'PtSd (PoSt TrAuMaTiC StReSs DiSoRdEr)' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
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
                      VCR.use_cassette('brd/disabilities') do
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
            end

            context 'is a valid string of characters' do
              it 'returns a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      VCR.use_cassette('brd/disabilities') do
                        post path, params: data, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
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
                      VCR.use_cassette('brd/disabilities') do
                        post path, params: data, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
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
                      VCR.use_cassette('brd/disabilities') do
                        post path, params: data, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:ok)
                      end
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
                    VCR.use_cassette('brd/disabilities') do
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
                      VCR.use_cassette('brd/disabilities') do
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
                  VCR.use_cassette('brd/disabilities') do
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
                  VCR.use_cassette('brd/disabilities') do
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

      describe "'disabilites' validations" do
        describe "'disabilities.classificationCode' validations" do
          context "when 'disabilites.classificationCode' is valid" do
            it 'returns a successful response' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
                      json_data = JSON.parse data
                      params = json_data
                      disabilities = [
                        {
                          disabilityActionType: 'NEW',
                          name: 'PTSD (post traumatic stress disorder)',
                          classificationCode: '5420',
                          secondaryDisabilities: [
                            {
                              name: 'PTSD personal trauma',
                              disabilityActionType: 'SECONDARY',
                              serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                            }
                          ]
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end
          end

          context "when 'disabilites.classificationCode' is invalid" do
            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json_data = JSON.parse data
                    params = json_data
                    disabilities = [
                      {
                        disabilityActionType: 'NEW',
                        name: 'PTSD (post traumatic stress disorder)',
                        classificationCode: '1111'
                      }
                    ]
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        describe "'disabilities.ratedDisabilityId' validations" do
          context "when 'disabilites.disabilityActionType' equals 'INCREASE'" do
            context "and 'disabilities.ratedDisabilityId' is not provided" do
              it 'returns an unprocessible entity status' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      disabilities = [
                        {
                          diagnosticCode: 123,
                          disabilityActionType: 'INCREASE',
                          name: 'PTSD (post traumatic stress disorder)'
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end

            context "and 'disabilities.ratedDisabilityId' is provided" do
              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      disabilities = [
                        {
                          diagnosticCode: 123,
                          ratedDisabilityId: '1100583',
                          disabilityActionType: 'INCREASE',
                          name: 'PTSD (post traumatic stress disorder)',
                          secondaryDisabilities: [
                            {
                              name: 'PTSD personal trauma',
                              disabilityActionType: 'SECONDARY',
                              serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                            }
                          ]
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end

            context "and 'disabilities.diagnosticCode' is not provided" do
              it 'returns an unprocessible entity status' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    disabilities = [
                      {
                        ratedDisabilityId: '1100583',
                        disabilityActionType: 'INCREASE',
                        name: 'PTSD (post traumatic stress disorder)'
                      }
                    ]
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end

          context "when 'disabilites.disabilityActionType' equals 'NONE'" do
            context "and 'disabilites.secondaryDisabilities' is defined" do
              context "and 'disabilites.diagnosticCode is not provided" do
                it 'returns an unprocessible entity status' do
                  with_okta_user(scopes) do |auth_header|
                    VCR.use_cassette('evss/claims/claims') do
                      VCR.use_cassette('brd/countries') do
                        json_data = JSON.parse data
                        params = json_data
                        disabilities = [
                          {
                            disabilityActionType: 'NONE',
                            name: 'PTSD (post traumatic stress disorder)',
                            secondaryDisabilities: [
                              {
                                name: 'PTSD personal trauma',
                                disabilityActionType: 'SECONDARY',
                                serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                              }
                            ]
                          }
                        ]
                        params['data']['attributes']['disabilities'] = disabilities
                        post path, params: params.to_json, headers: headers.merge(auth_header)
                        expect(response).to have_http_status(:unprocessable_entity)
                      end
                    end
                  end
                end
              end
            end
          end

          context "when 'disabilites.disabilityActionType' equals value other than 'INCREASE'" do
            context "and 'disabilities.ratedDisabilityId' is not provided" do
              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      disabilities = [
                        {
                          diagnosticCode: 123,
                          disabilityActionType: 'NEW',
                          name: 'PTSD (post traumatic stress disorder)',
                          secondaryDisabilities: [
                            {
                              name: 'PTSD personal trauma',
                              disabilityActionType: 'SECONDARY',
                              serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                            }
                          ]
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end
          end
        end

        describe "'disabilites.approximateDate' validations" do
          let(:disabilities) do
            [
              {
                disabilityActionType: 'NEW',
                name: 'PTSD (post traumatic stress disorder)',
                approximateDate: approximate_date,
                secondaryDisabilities: [
                  {
                    name: 'PTSD personal trauma',
                    disabilityActionType: 'SECONDARY',
                    serviceRelevance: 'Caused by a service-connected disability\\nLengthy description'
                  }
                ]
              }
            ]
          end

          context "when 'approximateDate' is in the future" do
            let(:approximate_date) { (Time.zone.today + 1.year).to_s }

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end

          context "when 'approximateDate' is in the past" do
            let(:approximate_date) { (Time.zone.today - 1.year).to_s }

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end
          end
        end
      end

      describe "'disabilities.secondaryDisabilities' validations" do
        context 'when disabilityActionType is NONE with secondaryDisabilities but no diagnosticCode' do
          it 'raises an exception' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      disabilityActionType: 'NONE',
                      name: 'PTSD (post traumatic stress disorder)',
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
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when secondaryDisability disabilityActionType is something other than SECONDARY' do
          it 'raises an exception' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NONE',
                    name: 'PTSD (post traumatic stress disorder)',
                    diagnosticCode: 9999,
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
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "when 'disabilites.secondaryDisabilities.classificationCode' is invalid" do
          it 'raises an exception' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      disabilityActionType: 'NONE',
                      name: 'PTSD (post traumatic stress disorder)',
                      diagnosticCode: 9999,
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
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "when 'disabilites.secondaryDisabilities.classificationCode' does not match name" do
          it 'raises an exception' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('brd/disabilities') do
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      disabilityActionType: 'NONE',
                      name: 'PTSD (post traumatic stress disorder)',
                      diagnosticCode: 9999,
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
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "when 'disabilites.secondaryDisabilities.approximateDate' is present" do
          it 'raises an exception if date is invalid' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NONE',
                    name: 'PTSD (post traumatic stress disorder)',
                    diagnosticCode: 9999,
                    secondaryDisabilities: [
                      {
                        disabilityActionType: 'SECONDARY',
                        name: 'PTSD',
                        serviceRelevance: 'Caused by a service-connected disability.',
                        approximateDate: '2019-02-30'
                      }
                    ]
                  }
                ]
                params['data']['attributes']['disabilities'] = disabilities
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end

          it 'raises an exception if date is not in the past' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NONE',
                    name: 'PTSD (post traumatic stress disorder)',
                    diagnosticCode: 9999,
                    secondaryDisabilities: [
                      {
                        disabilityActionType: 'SECONDARY',
                        name: 'PTSD',
                        serviceRelevance: 'Caused by a service-connected disability.',
                        approximateDate: "#{Time.zone.now.year + 1}-01-01"
                      }
                    ]
                  }
                ]
                params['data']['attributes']['disabilities'] = disabilities
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "when 'disabilites.secondaryDisabilities.classificationCode' is not present" do
          it 'raises an exception if name is not valid structure' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                disabilities = [
                  {
                    disabilityActionType: 'NONE',
                    name: 'PTSD (post traumatic stress disorder)',
                    diagnosticCode: 9999,
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
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end

          it 'raises an exception if name is longer than 255 characters' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      disabilityActionType: 'NONE',
                      name: 'PTSD (post traumatic stress disorder)',
                      diagnosticCode: 9999,
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
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when obligationTermsOfService is empty' do
          let(:empty_date) { '' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  tos =
                    json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['obligationTermsOfService'] # rubocop:disable Layout/LineLength
                  tos['startDate'] = empty_date
                  tos['endDate'] = empty_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when obligationTermsOfService startDate is after endDate' do
          let(:start_date) { '2022-09-04' }
          let(:end_date) { '2021-09-04' }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse(data)
                    tos =
                      json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['obligationTermsOfService'] # rubocop:disable Layout/LineLength
                    tos['startDate'] = start_date
                    tos['endDate'] = end_date
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        context 'when obligationTermsOfService startDate is missing' do
          let(:start_date) { nil }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['obligationTermsOfService']['startDate'] = # rubocop:disable Layout/LineLength
                    start_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when obligationTermsOfService endDate is missing' do
          let(:end_date) { nil }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['obligationTermsOfService']['endDate'] = # rubocop:disable Layout/LineLength
                    end_date
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when title10Activation' do
          context 'is missing anticipatedSeparationDate' do
            let(:anticipated_separation_date) { '' }

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['title10Activation']['anticipatedSeparationDate'] = # rubocop:disable Layout/LineLength
                      anticipated_separation_date
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end

          context 'when anticipatedSeparationDate is not in the future' do
            let(:anticipated_separation_date) { 1.month.ago.strftime('%Y-%m-%d') }

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
                      json = JSON.parse(data)
                      json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['title10Activation']['anticipatedSeparationDate'] = # rubocop:disable Layout/LineLength
                        anticipated_separation_date
                      data = json.to_json
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:unprocessable_entity)
                    end
                  end
                end
              end
            end
          end

          context 'is missing title10ActivationDate' do
            let(:title_10_activation_date) { '' }

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json = JSON.parse(data)
                    json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['title10Activation']['title10ActivationDate'] = # rubocop:disable Layout/LineLength
                      title_10_activation_date
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is not after the earliest servicePeriod.activeDutyBeginDate' do
            let(:title_10_activation_date) { '2005-05-05' }
            let(:service_periods) do
              [
                {
                  serviceBranch: 'Public Health Service',
                  activeDutyBeginDate: '1980-02-05',
                  activeDutyEndDate: '1990-01-02',
                  serviceComponent: 'Reserves',
                  separationLocationCode: 'ABCDEFGHIJKLMN'
                },
                {
                  serviceBranch: 'Public Health Service',
                  activeDutyBeginDate: '2006-02-05',
                  activeDutyEndDate: '2016-01-02',
                  serviceComponent: 'Active',
                  separationLocationCode: 'OPQRSTUVWXYZ'
                }
              ]
            end

            it 'responds with a 422' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('brd/disabilities') do
                      json = JSON.parse(data)
                      service_information = json['data']['attributes']['serviceInformation']
                      service_information['servicePeriods'] = service_periods
                      service_information['reservesNationalGuardService']['title10Activation']['title10ActivationDate'] = # rubocop:disable Layout/LineLength
                        title_10_activation_date
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

        context 'when unitName is empty' do
          let(:unit_name) { nil }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitName'] =
                    unit_name
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when unitPhone.areaCode has non-digits included' do
          let(:area_code) { '89X' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitPhone']['areaCode'] = # rubocop:disable Layout/LineLength
                    area_code
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when unitPhone.areaCode has wrong number of digits' do
          let(:area_code) { '1989' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitPhone']['areaCode'] = # rubocop:disable Layout/LineLength
                    area_code
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when unitPhone.phoneNumber has non-digits included' do
          let(:phone_number) { '89X6578' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitPhone']['phoneNumber'] = # rubocop:disable Layout/LineLength
                    phone_number
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when unitPhone.phoneNumber has wrong number of digits' do
          let(:phone_number) { '867530' }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitPhone']['phoneNumber'] = # rubocop:disable Layout/LineLength
                    phone_number
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when alternate names are duplicated' do
          let(:alternate_names) { %w[John Johnathan John] }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse(data)
                  json['data']['attributes']['serviceInformation']['alternateNames'] = alternate_names
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context 'when alternate names are duplicated with different cases' do
          let(:alternate_names) { %w[John Johnathan john] }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse(data)
                    json['data']['attributes']['serviceInformation']['alternateNames'] = alternate_names
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        context 'when direct deposit information does not include noAccount' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '123123123123',
              routingNumber: '123123123',
              financialInstitutionName: 'Global Bank',
              noAccount: nil
            }
          end

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        context 'when direct deposit information does not include a valid routing number' do
          let(:direct_deposit) do
            {
              accountType: 'CHECKING',
              accountNumber: '123123123123',
              routingNumber: '1234567891011121314',
              financialInstitutionName: 'Global Bank',
              noAccount: false
            }
          end

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse data
                  json['data']['attributes']['directDeposit'] = direct_deposit
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json = JSON.parse data
                  json['data']['attributes']['directDeposit'] = direct_deposit
                  data = json.to_json
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        context 'if no account is selected but a financial institution name is entered' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '',
              routingNumber: '',
              financialInstitutionName: 'Global Bank',
              noAccount: true
            }
          end

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        context 'if no account is selected and no other values are entered' do
          let(:direct_deposit) do
            {
              accountType: '',
              accountNumber: '',
              routingNumber: '',
              financialInstitutionName: '',
              noAccount: true
            }
          end

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  VCR.use_cassette('brd/disabilities') do
                    json = JSON.parse data
                    json['data']['attributes']['directDeposit'] = direct_deposit
                    data = json.to_json
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
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
