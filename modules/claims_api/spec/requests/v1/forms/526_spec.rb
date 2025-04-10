# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/standard_data_service'

RSpec.describe 'ClaimsApi::V1::Forms::526', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1956-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }
  let(:multi_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile, participant_id: nil, participant_ids: %w[123456789 987654321],
                                   birth_date: '19560506')
    )
  end
  let(:no_pid_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile, participant_id: nil, edipi: '123456', participant_ids: %w[])
    )
  end

  before do
    stub_poa_verification
    Timecop.freeze(Time.zone.now)
    stub_claims_api_auth_token
  end

  after do
    Timecop.return
  end

  describe '#526' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json').read }
    let(:parsed_codes) do
      {
        birls_id: '111985523',
        participant_id: '32397028'
      }
    end
    let(:add_response) { build(:add_person_response, parsed_codes:) }

    describe "'treatments' validations" do
      describe "'treatment.startDate' validations" do
        let(:treatments) do
          [
            {
              center: {
                name: 'Some Treatment Center',
                country: 'United States of America'
              },
              treatedDisabilityNames: [
                'PTSD (post traumatic stress disorder)'
              ],
              startDate: treatment_start_date
            }
          ]
        end

        context "when 'treatment.startDate' is prior to earliest 'servicePeriods.activeDutyBeginDate'" do
          let(:treatment_start_date) { '1970-01-01' }

          it 'returns a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "when 'treatment.startDate' is after earliest 'servicePeriods.activeDutyBeginDate'" do
          let(:treatment_start_date) { '1985-01-01' }

          it 'returns a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context "when 'treatment.startDate' is included but empty" do
          let(:treatment_start_date) { '' }

          it 'returns a 422' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "when 'treatment.startDate' is not included" do
          let(:treatments) do
            [
              {
                center: {
                  name: 'Some Treatment Center',
                  country: 'United States of America'
                },
                treatedDisabilityNames: [
                  'PTSD (post traumatic stress disorder)'
                ]
              }
            ]
          end

          it 'returns a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end
      end

      describe "'treatment.endDate' validations" do
        let(:treatments) do
          [
            {
              center: {
                name: 'Some Treatment Center',
                country: 'United States of America'
              },
              treatedDisabilityNames: [
                'PTSD (post traumatic stress disorder)'
              ],
              startDate: '1985-01-01',
              endDate: treatment_end_date
            }
          ]
        end

        context "when 'treatment.endDate' is before 'treatment.startDate'" do
          let(:treatment_end_date) { '1984-01-01' }

          it 'returns a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "when 'treatment.endDate' is after 'treatment.startDate'" do
          let(:treatment_end_date) { '1986-01-01' }

          it 'returns a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context "when 'treatment.endDate' is not provided" do
          let(:treatments) do
            [
              {
                center: {
                  name: 'Some Treatment Center',
                  country: 'United States of America'
                },
                treatedDisabilityNames: [
                  'PTSD (post traumatic stress disorder)'
                ],
                startDate: '1985-01-01'
              }
            ]
          end

          it 'returns a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end
      end

      describe "'treatments' validations" do
        let(:treatments) do
          [
            {
              center: {
                name: 'Some Treatment Center, with: commas and  double spaces',
                country: 'United States of America'
              },
              treatedDisabilityNames: treated_disability_names,
              startDate: '1985-01-01'
            }
          ]
        end

        context "when 'treatments[].center.country' is an empty string" do
          let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)'] }

          it 'returns a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                params['data']['attributes']['treatments'][0][:center][:country] = ''

                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "when 'treatments[].center.country' is too long" do
          let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)'] }

          it 'returns a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                params['data']['attributes']['treatments'][0][:center][:country] =
                  'Here\'s a country that has a very very very long name'

                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "when 'treatment.treatedDisabilityNames' includes value that does not match 'disability'" do
          let(:treated_disability_names) { ['not included in submitted disabilities collection'] }

          it 'returns a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "when 'treatment.treatedDisabilityNames' includes value that does match 'disability'" do
          let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)'] }

          it 'returns a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments

                  post path, params: params.to_json, headers: headers.merge(auth_header)

                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end

          context 'but has leading whitespace' do
            let(:treated_disability_names) { ['   PTSD (post traumatic stress disorder)'] }

            it 'returns a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'but has trailing whitespace' do
            let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)   '] }

            it 'returns a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'but has different casing' do
            let(:treated_disability_names) { ['PtSd (PoSt TrAuMaTiC StReSs DiSoRdEr)'] }

            it 'returns a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
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

    context 'when Veteran has all necessary identifiers' do
      describe 'schema' do
        it 'returns a successful get response with json schema' do
          get path
          json_schema = JSON.parse(response.body)['data'][0]
          expect(json_schema).to eq(JSON.parse(schema))
        end
      end

      it 'returns a successful response with all the data' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              parsed = JSON.parse(response.body)
              expect(parsed['data']['type']).to eq('claims_api_claim')
              expect(parsed['data']['attributes']['status']).to eq('pending')
            end
          end
        end
      end

      context 'when autoCestPDFGenerationDisabled is false' do
        let(:auto_cest_pdf_generation_disabled) { false }

        it 'creates the sidekick job' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
                post path, params: data, headers: headers.merge(auth_header)
              end
            end
          end
        end
      end

      context 'when autoCestPDFGenerationDisabled is true' do
        let(:auto_cest_pdf_generation_disabled) { true }

        it 'creates the sidekick job', skip: 'No expectation in this example' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                post path, params: data, headers: headers.merge(auth_header)
              end
            end
          end
        end
      end

      it 'assigns a source' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.source).to eq('abraham lincoln')
            end
          end
        end
      end

      it "assigns a 'cid' (OKTA client_id)" do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              jwt_payload = {
                'ver' => 1,
                'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
                'iss' => 'https://example.com/oauth2/default',
                'aud' => 'api://default',
                'iat' => Time.current.utc.to_i,
                'exp' => Time.current.utc.to_i + 3600,
                'cid' => '0oa41882gkjtBRJhu2p7',
                'uid' => '00u1zlqhuo3yLa2Xs2p7',
                'scp' => %w[claim.write],
                'sub' => 'ae9ff5f4e4b741389904087d94cd19b2',
                'icn' => '1013062086V794840'
              }
              allow_any_instance_of(ClaimsApi::ValidatedToken).to receive(:payload).and_return(jwt_payload)

              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.cid).to eq(jwt_payload['cid'])
              expect(aec.veteran_icn).to eq(jwt_payload['icn'])
            end
          end
        end
      end

      it 'sets the flashes' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.flashes).to eq(%w[Hardship Homeless])
            end
          end
        end
      end

      it 'sets the special issues' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.special_issues).to eq([{ 'code' => 9999,
                                                  'name' => 'PTSD (post traumatic stress disorder)',
                                                  'special_issues' => %w[FDC PTSD/2] }])
            end
          end
        end
      end

      it 'builds the auth headers' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              auth_header_stub = instance_double(EVSS::DisabilityCompensationAuthHeaders)
              expect(EVSS::DisabilityCompensationAuthHeaders).to(receive(:new).once { auth_header_stub })
              expect(auth_header_stub).to receive(:add_headers).once
              post path, params: data, headers: headers.merge(auth_header)
            end
          end
        end
      end

      context 'when changeOfAddress information is submitted' do
        let(:json_data) { JSON.parse data }

        values = %w[TEMPORARY Temporary temporary]
        values.each do |value|
          context "when addressChangeType is #{value}" do
            context 'when beginningDate is in the past' do
              let(:json_data) { JSON.parse data }
              let(:change_of_address) do
                {
                  beginningDate: 1.month.ago.to_date.to_s,
                  endingDate: 1.month.from_now.to_date.to_s,
                  addressChangeType: value,
                  addressLine1: '1234 Couch Street',
                  city: 'New York City',
                  state: 'NY',
                  type: 'DOMESTIC',
                  zipFirstFive: '12345',
                  country: 'USA'
                }
              end

              it 'raises an exception that beginningDate is not valid' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/intake_sites') do
                    VCR.use_cassette('claims_api/brd/countries') do
                      par = json_data
                      par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address
                      par['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                        '2007-08-01'

                      post path, params: par.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end

            context 'when the endingDate is not provided' do
              let(:json_data) { JSON.parse data }
              let(:change_of_address) do
                {
                  beginningDate: 1.month.from_now.to_date.to_s,
                  addressChangeType: value,
                  addressLine1: '1234 Couch Street',
                  city: 'New York City',
                  state: 'NY',
                  type: 'DOMESTIC',
                  zipFirstFive: '12345',
                  country: 'USA'
                }
              end

              it 'raises an exception that endingDate is not valid' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/intake_sites') do
                    VCR.use_cassette('claims_api/brd/countries') do
                      par = json_data
                      par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address
                      par['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                        '2007-08-01'

                      post path, params: par.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end

            context 'when the beginningDate is after the endingDate' do
              let(:json_data) { JSON.parse data }
              let(:change_of_address) do
                {
                  beginningDate: 1.month.from_now.to_date.to_s,
                  endingDate: 1.month.ago.to_date.to_s,
                  addressChangeType: value,
                  addressLine1: '1234 Couch Street',
                  city: 'New York City',
                  state: 'NY',
                  type: 'DOMESTIC',
                  zipFirstFive: '12345',
                  country: 'USA'
                }
              end

              it 'raises an exception that endingDate is not valid' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/intake_sites') do
                    VCR.use_cassette('claims_api/brd/countries') do
                      par = json_data
                      par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address
                      par['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                        '2007-08-01'

                      post path, params: par.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end
          end
        end

        context 'when addressChangeType is PERMANENT' do
          let(:value) { 'PERMANENT' }

          context 'when the endingDate is provided' do
            let(:json_data) { JSON.parse data }
            let(:change_of_address) do
              {
                beginningDate: 1.month.from_now.to_date.to_s,
                endingDate: 2.months.from_now.to_date.to_s,
                addressChangeType: value,
                addressLine1: '1234 Couch Street',
                city: 'New York City',
                state: 'NY',
                type: 'DOMESTIC',
                zipFirstFive: '12345',
                country: 'USA'
              }
            end

            it 'raises an exception that endingDate is not valid' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/intake_sites') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address
                    par['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                      '2007-08-01'

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end
        end

        context 'when an invalid country is submitted' do
          let(:change_of_address) do
            {
              beginningDate: 1.month.from_now.to_date.to_s,
              addressChangeType: 'PERMANENT',
              addressLine1: '1234 Couch Street',
              city: 'New York City',
              state: 'NY',
              type: 'DOMESTIC',
              zipFirstFive: '12345',
              country: 'BlahBlahBlah'
            }
          end

          it 'raises an exception that country is invalid' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/intake_sites') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end
      end

      describe 'activeDutyEndDate within 180 days' do
        let(:json_data) { JSON.parse data }

        before do
          allow_any_instance_of(ClaimsApi::DisabilityCompensationValidations)
            .to receive(:validate_form_526_location_codes!).and_return(nil)
          allow_any_instance_of(ClaimsApi::DisabilityCompensationValidations)
            .to receive(:validate_form_526_current_mailing_address!).and_return(nil)
        end

        context 'when activeDutyEndDate is beyond 180 days from now' do
          let(:service_periods) do
            [
              {
                'activeDutyBeginDate' => 4.years.ago.to_date.to_s,
                'activeDutyEndDate' => 181.days.from_now.to_date.to_s,
                'serviceBranch' => 'Navy'
              }
            ]
          end

          it 'returns a bad request response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                par = json_data
                par['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods

                post path, params: par.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context 'when activeDutyEndDate is exactly 180 days from now' do
          let(:service_periods) do
            [
              {
                'activeDutyBeginDate' => 4.years.ago.to_date.to_s,
                'activeDutyEndDate' => 180.days.from_now.to_date.to_s,
                'serviceBranch' => 'Navy'
              }
            ]
          end

          it 'returns a successful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                par = json_data
                par['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods

                post path, params: par.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end

        context 'when activeDutyEndDate is less than 180 days from now' do
          let(:service_periods) do
            [
              {
                'activeDutyBeginDate' => 4.years.ago.to_date.to_s,
                'activeDutyEndDate' => 179.days.from_now.to_date.to_s,
                'serviceBranch' => 'Navy'
              }
            ]
          end

          it 'returns a successful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                par = json_data
                par['data']['attributes']['serviceInformation']['servicePeriods'] = service_periods

                post path, params: par.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end
      end

      # lines 89-92 in disability_compensation_validations.rb checks phone number for dash
      context 'when reservesNationalGuardService information is submitted' do
        let(:json_data) { JSON.parse data }
        let(:title10_activation_date) { 1.day.ago.to_date.to_s }
        let(:anticipated_separation_date) { 1.year.from_now.to_date.to_s }
        let(:reserves_national_guard_service) do
          {
            obligationTermOfServiceFromDate: 1.year.ago.to_date.to_s,
            obligationTermOfServiceToDate: 6.months.ago.to_date.to_s,
            unitName: 'best-name-ever',
            unitPhone: {
              areaCode: '555',
              phoneNumber: '555-5555'
            },
            receivingInactiveDutyTrainingPay: true,
            title10Activation: {
              anticipatedSeparationDate: anticipated_separation_date,
              title10ActivationDate: title10_activation_date
            }
          }
        end

        context "When an activeDutyBeginDate is before a Veteran's 13th birthday" do
          it 'raise an error' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  headers['X-VA-Birth-Date'] = '1986-05-06T00:00:00+00:00'
                  par = json_data
                  par['data']['attributes']['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] =
                    '2007-08-01'

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "'title10ActivationDate' validations" do
          context 'when title10ActivationDate is prior to earliest servicePeriod.activeDutyBeginDate' do
            let(:title10_activation_date) { '1980-02-04' }

            it 'raises an exception that title10ActivationDate is invalid' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is same day as earliest servicePeriod.activeDutyBeginDate' do
            let(:title10_activation_date) { '1980-02-05' }

            it 'raises an exception that title10ActivationDate is invalid' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end

          context 'when title10ActivationDate is after earliest servicePeriod.activeDutyBeginDate but before today' do
            let(:title10_activation_date) { '1980-02-06' }

            it 'returns a successful response' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is today' do
            let(:title10_activation_date) { Time.zone.now.to_date.to_s }

            it 'returns a successful response' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is tomorrow' do
            let(:title10_activation_date) { 1.day.from_now.to_date.to_s }

            it 'raises an exception that title10ActivationDate is invalid' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end

        context "'anticipatedSeparationDate' validations" do
          context "when 'anticipatedSeparationDate' is in the past" do
            let(:anticipated_separation_date) { 1.day.ago.to_date.to_s }

            it "raises an exception that 'anticipatedSeparationDate' is invalid" do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end

          context "when 'anticipatedSeparationDate' is today" do
            let(:anticipated_separation_date) { 1.hour.ago.to_date.to_s }

            it "raises an exception that 'anticipatedSeparationDate' is invalid" do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end

          context "when 'anticipatedSeparationDate' is in the future" do
            let(:anticipated_separation_date) { 1.day.from_now.to_date.to_s }

            it 'returns a successful response' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        context "when 'unitName' is empty" do
          let(:unit_name) { '' }

          it 'returns a successful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitName'] =
                    unit_name

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                  response_body = JSON.parse(response.body)
                  claim_id = response_body['data']['id']
                  claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)
                  claim.to_internal
                  expect(claim.form_data['serviceInformation']['reservesNationalGuardService']['unitName']).to eq(' ')
                end
              end
            end
          end
        end

        context "when 'unitName' is blank space" do
          let(:unit_name) { ' ' }

          it 'returns a successful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitName'] =
                    unit_name

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                  response_body = JSON.parse(response.body)
                  claim_id = response_body['data']['id']
                  claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)
                  claim.to_internal
                  expect(claim.form_data['serviceInformation']['reservesNationalGuardService']['unitName']).to eq(' ')
                end
              end
            end
          end
        end

        context "when 'unitName' is nil" do
          let(:unit_name) { nil }

          it 'returns a unsuccessful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService']['unitName'] =
                    unit_name

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "when 'unitName' is not present" do
          it 'returns a unsuccessful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'].delete('unitName')

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end

        context "when 'serviceInformation' is not present" do
          it 'returns a unsuccessful response' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  par = json_data
                  par['data']['attributes'].delete('serviceInformation')

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end
        end
      end

      context '526 submission payload validations' do
        let(:json_data) { JSON.parse data }

        # rubocop:disable Layout/LineLength
        it 'doesn\'t allow additional fields' do
          mock_acg(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['serviceInformation']['someBadField'] = 'someValue'
            params['data']['attributes']['anotherBadField'] = 'someValue'

            post path, params: params.to_json, headers: headers.merge(auth_header)

            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(2)
            expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
              'The property /serviceInformation/someBadField is not defined on the schema. Additional properties are not allowed'
            )
            expect(JSON.parse(response.body)['errors'][1]['detail']).to eq(
              'The property /anotherBadField is not defined on the schema. Additional properties are not allowed'
            )
          end
        end
        # rubocop:enable Layout/LineLength

        it 'requires currentMailingAddress subfields' do
          mock_acg(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['veteran']['currentMailingAddress'] = {}
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(5)
          end
        end

        it 'removes the dash in homelessness primary phone' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                par = json_data
                par['data']['attributes']['veteran']['homelessness']['pointOfContact']['primaryPhone']['phoneNumber'] =
                  '555-5555'
                post path, params: par.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end

        it 'requires homelessness currentlyHomeless subfields' do
          mock_acg(scopes) do |auth_header|
            par = json_data
            par['data']['attributes']['veteran']['homelessness'] = {
              pointOfContact: {
                pointOfContactName: 'John Doe',
                primaryPhone: {
                  areaCode: '555',
                  phoneNumber: '555-5555'
                }
              },
              currentlyHomeless: {
                homelessSituationType: 'NOT_A_HOMELESS_TYPE',
                otherLivingSituation: 'other living situations'
              }
            }
            post path, params: par.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(1)
          end
        end

        it 'requires homelessness homelessnessRisk subfields' do
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            mock_acg(scopes) do |auth_header|
              par = json_data
              par['data']['attributes']['veteran']['homelessness'] = {
                pointOfContact: {
                  pointOfContactName: 'John Doe',
                  primaryPhone: {
                    areaCode: '555',
                    phoneNumber: '555-5555'
                  }
                },
                homelessnessRisk: {
                  homelessnessRiskSituationType: 'NOT_A_RISK_TYPE',
                  otherLivingSituation: 'other living situations'
                }
              }
              post path, params: par.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:unprocessable_entity)
              expect(JSON.parse(response.body)['errors'].size).to eq(1)
            end
          end
        end

        it 'requires disability subfields' do
          mock_acg(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['disabilities'] = [{}]
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(4)
          end
        end

        describe 'disabilities specialIssues' do
          context 'when an incorrect type is passed for specialIssues' do
            it 'returns errors explaining the failure' do
              mock_acg(scopes) do |auth_header|
                params = json_data
                params['data']['attributes']['disabilities'][0]['specialIssues'] = ['invalidType']
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
                expect(JSON.parse(response.body)['errors'].size).to eq(1)
              end
            end
          end

          context 'when correct types are passed for specialIssues' do
            it 'returns a successful status' do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  mock_acg(scopes) do |auth_header|
                    params = json_data
                    params['data']['attributes']['disabilities'][0]['specialIssues'] = %w[ALS PTSD/1]
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        describe 'flashes' do
          context 'when an incorrect type is passed for flashes' do
            it 'returns errors explaining the failure' do
              mock_acg(scopes) do |auth_header|
                params = json_data
                params['data']['attributes']['veteran']['flashes'] = ['invalidType']
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
                expect(JSON.parse(response.body)['errors'].size).to eq(1)
              end
            end
          end

          context 'when correct types are passed for flashes' do
            it 'returns a successful status' do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  mock_acg(scopes) do |auth_header|
                    params = json_data
                    params['data']['attributes']['veteran']['flashes'] = %w[Hardship POW]
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        it 'requires international postal code when address type is international' do
          mock_acg(scopes) do |auth_header|
            params = json_data
            mailing_address = params['data']['attributes']['veteran']['currentMailingAddress']
            mailing_address['type'] = 'INTERNATIONAL'
            params['data']['attributes']['veteran']['currentMailingAddress'] = mailing_address

            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(1)
          end
        end

        it 'responds with a 422 when request.body is a Puma::NullIO' do
          fake_puma_null_io_object = Object.new.tap do |obj|
            def obj.class
              OpenStruct.new name: 'Puma::NullIO'
            end
          end
          expect(fake_puma_null_io_object.class.name).to eq 'Puma::NullIO'
          allow_any_instance_of(ActionDispatch::Request).to(
            receive(:body).and_return(fake_puma_null_io_object)
          )
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response).to have_http_status :unprocessable_entity
              expect(JSON.parse(response.body)['errors']).to be_an Array
            end
          end
        end

        context 'responds with a 422 when request.body isn\'t a JSON *object*' do
          before do
            fake_io_object = OpenStruct.new read: json
            allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
          end

          context 'request.body is a JSON string' do
            let(:json) { '"Hello!"' }

            it 'responds with a properly formed error object' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  body = JSON.parse(response.body)
                  expect(response).to have_http_status :unprocessable_entity
                  expect(body['errors']).to be_an Array
                  expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object: #{json}"
                end
              end
            end
          end

          context 'request.body is a JSON integer' do
            let(:json) { '66' }

            it 'responds with a properly formed error object' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  body = JSON.parse(response.body)
                  expect(response).to have_http_status :unprocessable_entity
                  expect(body['errors']).to be_an Array
                  expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object: #{json}"
                end
              end
            end
          end
        end
      end

      context 'form 526 validation endpoint' do
        let(:path) { '/services/claims/v1/forms/526/validate' }

        it 'returns a successful response when valid' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/v1/disability_comp/validate') do
                  post path, params: data, headers: headers.merge(auth_header)
                  parsed = JSON.parse(response.body)
                  expect(parsed['data']['type']).to eq('claims_api_auto_established_claim_validation')
                  expect(parsed['data']['attributes']['status']).to eq('valid')
                end
              end
            end
          end
        end

        it 'returns a list of errors when invalid hitting EVSS' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/v1/disability_comp/invalid') do
                  post path, params: data, headers: headers.merge(auth_header)
                  parsed = JSON.parse(response.body)
                  expect(parsed['errors'][0]['title']).to eq('Internal server error')
                end
              end
            end
          end
        end

        it 'increment counters for statsd' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/evss/disability_compensation_form/form_526_invalid_validation') do
              expect(StatsD).to receive(:increment).at_least(:once)
              post path, params: data, headers: headers.merge(auth_header)
            end
          end
        end

        it 'returns a list of errors when invalid via internal validation' do
          mock_acg(scopes) do |auth_header|
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['veteran']['currentMailingAddress'] = {}
            post path, params: params.to_json, headers: headers.merge(auth_header)
            parsed = JSON.parse(response.body)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(parsed['errors'].size).to eq(5)
          end
        end

        context 'Timeouts are recorded (investigating)' do
          [Common::Exceptions::GatewayTimeout, Timeout::Error, Faraday::TimeoutError].each do |error_klass|
            context error_klass.to_s do
              it 'is logged to PersonalInformationLog', skip: 'No expectation in this example' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/countries') do
                    VCR.use_cassette('claims_api/bgs/claims/claims') do
                      allow_any_instance_of(ClaimsApi::DisabilityCompensation::MockOverrideService)
                        .to receive(:validate_form526).and_raise(error_klass)
                      allow_any_instance_of(EVSS::DisabilityCompensationForm::Service)
                        .to receive(:validate_form526).and_raise(error_klass)
                      allow_any_instance_of(ClaimsApi::EVSSService::Base)
                        .to receive(:validate).and_raise(error_klass)
                      post path, params: data, headers: headers.merge(auth_header)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    context 'when veteran is missing EDIPI' do
      let(:no_edipi_target_veteran) do
        OpenStruct.new(
          icn: '1012832025V743496',
          first_name: 'Wesley',
          last_name: 'Ford',
          birth_date: '19590211',
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
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::DisabilityCompensationController)
              .to receive(:target_veteran).and_return(no_edipi_target_veteran)
            post path, params: data, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.parsed_body['errors'][0]['detail']).to eq(
              "Unable to locate Veteran's EDIPI in Master Person Index (MPI). " \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
            )
          end
        end
      end
    end

    context 'when Veteran is missing a participant_id' do
      before do
        stub_mpi_not_found
      end

      context 'when consumer is representative' do
        it 'returns an unprocessable entity status' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end

      context 'when consumer is Veteran' do
        let(:parsed_codes) do
          {
            birls_id: '111985523',
            participant_id: '32397028'
          }
        end
        let(:profile_with_edipi) do
          MPI::Responses::FindProfileResponse.new(
            status: 'OK',
            profile: build(:mpi_profile, edipi: '2536798', birth_date: '19560506')
          )
        end
        let(:profile) { build(:mpi_profile, birth_date: '19560506') }
        let(:mpi_profile_response) { build(:find_profile_response, profile:) }

        it 'returns a 422 without an edipi' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                VCR.use_cassette('claims_api/mpi/add_person/add_person_success') do
                  VCR.use_cassette('claims_api/mpi/find_candidate/orch_search_with_attributes') do
                    allow_any_instance_of(MPIData)
                      .to receive(:mvi_response).and_return(multi_profile)
                    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
                      .and_return(mpi_profile_response)
                    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes_with_orch_search)
                      .and_return(mpi_profile_response)

                    post path, params: data, headers: auth_header

                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end
          end
        end

        it 'adds person to MPI and checks for edipi' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                VCR.use_cassette('claims_api/mpi/add_person/add_person_success') do
                  VCR.use_cassette('claims_api/mpi/find_candidate/orch_search_with_attributes') do
                    allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(true)
                    allow_any_instance_of(MPIData).to receive(:mvi_response)
                      .and_return(profile_with_edipi)

                    post path, params: data, headers: auth_header
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end
      end

      context 'when consumer is Veteran, but is missing a participant id' do
        let(:add_person_proxy_response) do
          instance_double(MPI::Responses::AddPersonResponse, ok?: true, status: :ok)
        end

        it 'raises a 422, with message' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                allow_any_instance_of(ClaimsApi::Veteran)
                  .to receive(:mpi_record?).and_return(true)
                allow_any_instance_of(MPIData)
                  .to receive(:mvi_response).and_return(no_pid_profile)
                allow_any_instance_of(MPIData)
                  .to receive(:add_person_proxy).and_return(add_person_proxy_response)

                parsed_data = JSON.parse(data)
                post path, params: parsed_data, headers: headers.merge(auth_header), as: :json

                json_response = JSON.parse(response.body)

                expect(response).to have_http_status(:unprocessable_entity)
                expect(json_response['errors'][0]['detail']).to eq(
                  "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
                  'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
                )
              end
            end
          end
        end
      end
    end

    context 'when Veteran has participant_id' do
      context 'when Veteran is missing a birls_id' do
        before do
          stub_mpi(build(:mpi_profile, birls_id: nil, birth_date: '19560506'))
        end

        it 'returns an unprocessable entity status' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end
    end

    context 'when Veteran has multiple participant_ids' do
      before do
        stub_mpi(build(:mpi_profile, birls_id: nil, birth_date: '19560506'))
      end

      it 'returns an unprocessable entity status' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/countries') do
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              allow_any_instance_of(ClaimsApi::Veteran)
                .to receive(:mpi_record?).and_return(true)
              allow_any_instance_of(MPIData)
                .to receive(:mvi_response).and_return(multi_profile)
              allow_any_instance_of(MPIData)
                .to receive(:add_person_proxy).and_return(add_response)

              post path, params: data, headers: headers.merge(auth_header)
              data = JSON.parse(response.body)
              expect(response).to have_http_status(:unprocessable_entity)
              expect(data['errors'][0]['detail']).to eq(
                'Veteran has multiple active Participant IDs in Master Person Index (MPI). ' \
                'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
              )
            end
          end
        end
      end
    end

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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end
      end

      context 'when UTC is same day as the US Central Time Zone day' do
        before do
          Timecop.freeze(Time.parse('2022-05-01 12:00:00 UTC'))
        end

        after do
          Timecop.return
        end

        context "and 'claim_date' is the current day" do
          let(:claim_date) { Time.zone.today.to_s }

          it 'responds with a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end

        context "and 'claim_date' is in the future" do
          let(:claim_date) { (Time.zone.today + 1.day).to_s }

          it 'responds with bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (iso w/Z)" do
          let(:claim_date) { 1.day.ago.iso8601 }

          it 'responds with a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
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
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (TZ String)" do
          let(:claim_date) { 1.day.ago.to_s }

          it 'responds with a 422' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (w/out T)" do
          let(:claim_date) { 1.day.ago.iso8601.sub('T', ' ') }

          it 'responds with a 422' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "and 'claim_date' improperly formatted (hello world)" do
          let(:claim_date) { 'hello world' }

          it 'responds with bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end

        context "and 'claim_date' improperly formatted (empty string)" do
          let(:claim_date) { '' }

          it 'responds with bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
              end
            end
          end
        end
      end
    end

    context 'when submitted application_expiration_date is in the past' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['applicationExpirationDate'] = (Time.zone.today - 1.day).to_s
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'when submitted application_expiration_date is today' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/countries') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['applicationExpirationDate'] = Time.zone.today.to_s
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'when submitted application_expiration_date is in the future' do
      it 'responds with a 200' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:ok)
            end
          end
        end
      end
    end

    context 'when submitted claimant_certification is false' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['claimantCertification'] = false
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'when submitted separationLocationCode is missing for a future activeDutyEndDate' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/intake_sites') do
            VCR.use_cassette('claims_api/brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['serviceInformation']['servicePeriods'].first['activeDutyEndDate'] =
                (Time.zone.today + 10.days).to_s
              post path, params: params.to_json, headers: headers.merge(auth_header)
              json = JSON.parse(response.body)
              expect(response).to have_http_status(:bad_request)
              expect(json['errors'][0]['title']).to eq('Invalid field value')
            end
          end
        end
      end
    end

    context 'when submitted separationLocationCode is invalid' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/intake_sites') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['activeDutyEndDate'] =
              (Time.zone.today + 1.day).to_s
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['separationLocationCode'] =
              '11111111111'
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:bad_request)
            response_error_details = JSON.parse(response.body)['errors'].first['detail']
            expect(response_error_details).to include('is not a valid value for "separationLocationCode"')
          end
        end
      end
    end

    context 'when submitted separationLocationCode is an integer' do
      it 'responds with bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/intake_sites') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['activeDutyEndDate'] =
              (Time.zone.today + 1.day).to_s
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['separationLocationCode'] =
              111
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            response_error_details = JSON.parse(response.body)['errors'].first['detail']
            expect(response_error_details).to include('Code must match the values returned by the /intake-sites' \
                                                      ' endpoint on the [Benefits reference Data API]')
          end
        end
      end
    end

    context 'when confinements don\'t fall within service periods' do
      it 'responds with a bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['serviceInformation']['confinements'] = [{
                confinementBeginDate: (Time.zone.today - 2.weeks).to_s,
                confinementEndDate: (Time.zone.today + 1.week).to_s
              }]
              post path, params: params.to_json, headers: headers.merge(auth_header)
              response_error_details = JSON.parse(response.body)['errors'].first['detail']
              expect(response).to have_http_status(:bad_request)
              expect(response_error_details).to include('confinements must be within a service period')
            end
          end
        end
      end
    end

    context 'when confinements are overlapping' do
      it 'responds with a bad request' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/brd/countries') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['serviceInformation']['confinements'] = [{
              confinementBeginDate: '1980-03-05',
              confinementEndDate: '1985-01-07'
            }, {
              confinementBeginDate: '1985-01-05',
              confinementEndDate: '1989-04-05'

            }]
            post path, params: params.to_json, headers: headers.merge(auth_header)
            response_error_details = JSON.parse(response.body)['errors'].first['detail']
            expect(response).to have_http_status(:bad_request)
            expect(response_error_details).to include('confinements must not overlap other confinements')
          end
        end
      end
    end

    describe 'Veteran homelessness validations' do
      context "when 'currentlyHomeless' and 'homelessnessRisk' are both provided" do
        it 'responds with a 422' do
          mock_acg(scopes) do |auth_header|
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['veteran']['homelessness']['currentlyHomeless'] = {
              homelessSituationType: 'fleeing',
              otherLivingSituation: 'community help center'
            }
            params['data']['attributes']['veteran']['homelessness']['homelessnessRisk'] = {
              homelessnessRiskSituationType: 'losingHousing',
              otherLivingSituation: 'community help center'
            }
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            response_body = JSON.parse(response.body)
            expect(response_body['errors'].length).to eq(1)
            expect(response_body['errors'][0]['detail']).to eq(
              "Must define only one of 'veteran.homelessness.currentlyHomeless' or " \
              "'veteran.homelessness.homelessnessRisk'"
            )
          end
        end
      end

      context "when neither 'currentlyHomeless' nor 'homelessnessRisk' is provided" do
        context "when 'pointOfContact' is provided" do
          it 'responds with a 422' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['veteran']['homelessness'] = {}
                  params['data']['attributes']['veteran']['homelessness']['pointOfContact'] = {
                    pointOfContactName: 'Jane Doe',
                    primaryPhone: {
                      areaCode: '555',
                      phoneNumber: '5555555'
                    }
                  }
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'].length).to eq(1)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If 'veteran.homelessness.pointOfContact' is defined, then one of " \
                    "'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk'" \
                    ' is required'
                  )
                end
              end
            end
          end
        end
      end

      context "when either 'currentlyHomeless' or 'homelessnessRisk' is provided" do
        context "when 'pointOfContact' is not provided" do
          it 'responds with a 422' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['homelessness']['currentlyHomeless'] = {
                  homelessSituationType: 'fleeing',
                  otherLivingSituation: 'community help center'
                }
                params['data']['attributes']['veteran']['homelessness'].delete('pointOfContact')
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:unprocessable_entity)
                response_body = JSON.parse(response.body)
                expect(response_body['errors'].length).to eq(1)
                expect(response_body['errors'][0]['detail']).to eq(
                  "If one of 'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk' is" \
                  " defined, then 'veteran.homelessness.pointOfContact' is required"
                )
              end
            end
          end
        end
      end
    end

    describe "'servicePay validations'" do
      describe "'servicePay.militaryRetiredPay' validations" do
        describe "'receiving' and 'willReceiveInFuture' validations" do
          let(:service_pay_attribute) do
            {
              militaryRetiredPay: {
                receiving:,
                willReceiveInFuture: will_receive,
                futurePayExplanation: 'Some explanation',
                payment: {
                  serviceBranch: 'Air Force'
                }
              }
            }
          end

          context "when 'receiving' and 'willReceiveInFuture' are equal but not 'nil'" do
            context "when both are 'true'" do
              let(:receiving) { true }
              let(:will_receive) { true }

              it 'responds with a bad request' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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

            context "when both are 'false'" do
              let(:receiving) { false }
              let(:will_receive) { false }

              it 'responds with a bad request' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/countries') do
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

          context "when 'receiving' and 'willReceiveInFuture' are not equal" do
            context "when 'receiving' is 'false' and 'willReceiveInFuture' is 'true'" do
              let(:receiving) { false }
              let(:will_receive) { true }

              it 'responds with a 200' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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

            context "when 'receiving' is 'true' and 'willReceiveInFuture' is 'false'" do
              let(:receiving) { true }
              let(:will_receive) { false }

              it 'responds with a 200' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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

        describe "'payment'" do
          let(:service_pay_attribute) do
            {
              militaryRetiredPay: {
                receiving: true,
                willReceiveInFuture: false,
                payment: {
                  serviceBranch: 'Air Force',
                  amount: military_retired_payment_amount
                }
              }
            }
          end

          context "when 'amount' is below the minimum" do
            let(:military_retired_payment_amount) { 0 }

            it 'responds with an unprocessable entity' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "when 'amount' is above the maximum" do
            let(:military_retired_payment_amount) { 1_000_000 }

            it 'responds with an unprocessable entity' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

          context "when 'amount' is within limits" do
            let(:military_retired_payment_amount) { 100 }

            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

        describe "'futurePayExplanation'" do
          context "when 'militaryRetiredPay.willReceiveInFuture' is 'true'" do
            let(:will_receive_in_future) { true }

            context "when 'militaryRetiredPay.futurePayExplanation' is not provided" do
              let(:service_pay_attribute) do
                {
                  militaryRetiredPay: {
                    receiving: false,
                    willReceiveInFuture: will_receive_in_future,
                    payment: {
                      serviceBranch: 'Air Force'
                    }
                  }
                }
              end

              it 'responds with an unprocessable entity' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:unprocessable_entity)
                  end
                end
              end
            end

            context "when 'militaryRetiredPay.futurePayExplanation' is provided" do
              let(:service_pay_attribute) do
                {
                  militaryRetiredPay: {
                    receiving: false,
                    willReceiveInFuture: will_receive_in_future,
                    futurePayExplanation: 'Retiring soon.',
                    payment: {
                      serviceBranch: 'Air Force'
                    }
                  }
                }
              end

              it 'responds with a 200' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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

      describe "'servicePay.separationPay' validations" do
        describe "'payment'" do
          let(:service_pay_attribute) do
            {
              separationPay: {
                received: true,
                receivedDate: (Time.zone.today - 1.year).to_s,
                payment: {
                  serviceBranch: 'Air Force',
                  amount: separation_payment_amount
                }
              }
            }
          end

          context "when 'amount' is below the minimum" do
            let(:separation_payment_amount) { 0 }

            it 'responds with an unprocessable entity' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end
          end

          context "when 'amount' is above the maximum" do
            let(:separation_payment_amount) { 1_000_000 }

            it 'responds with an unprocessable entity' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

          context "when 'amount' is within limits" do
            let(:separation_payment_amount) { 100 }

            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

        describe "'receivedDate'" do
          let(:service_pay_attribute) do
            {
              separationPay: {
                received: true,
                receivedDate: received_date,
                payment: {
                  serviceBranch: 'Air Force',
                  amount: 100
                }
              }
            }
          end

          context "when 'receivedDate' is not in the past" do
            let(:received_date) { Time.zone.today.to_s }

            it 'responds with a bad request' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end

          context "when 'receivedDate' is in the past" do
            let(:received_date) { (Time.zone.today - 1.year).to_s }

            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

    describe "'disabilities.secondaryDisabilities' validations" do
      context 'when disabilityActionType is NONE without secondaryDisabilities' do
        it 'raises an exception' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              json_data = JSON.parse data
              params = json_data
              disabilities = [
                {
                  disabilityActionType: 'NONE',
                  name: 'PTSD (post traumatic stress disorder)'
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:bad_request)
            end
          end
        end
      end

      context 'when secondaryDisability disabilityActionType is something other than SECONDARY' do
        it 'raises an exception' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
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

      context "when 'disabilities.secondaryDisabilities.classificationCode' is invalid" do
        let(:classification_type_codes) { [{ clsfcn_id: '1111' }] }

        [true, false].each do |flipped|
          context "when feature flag is #{flipped}" do
            before do
              allow(Flipper).to receive(:enabled?).with(:claims_api_526_validations_v1_local_bgs).and_return(flipped)
              allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return(flipped)
              if flipped
                expect_any_instance_of(ClaimsApi::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              else
                expect_any_instance_of(BGS::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              end
            end

            it 'raises an exception' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
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
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end
      end

      context "when 'disabilities.secondaryDisabilities.classificationCode' does not match name" do
        let(:classification_type_codes) { [{ clsfcn_id: '1111' }] }

        [true, false].each do |flipped|
          context "when feature flag is #{flipped}" do
            before do
              allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return(flipped)
              allow(Flipper).to receive(:enabled?).with(:claims_api_526_validations_v1_local_bgs).and_return(flipped)
              if flipped
                expect_any_instance_of(ClaimsApi::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              else
                expect_any_instance_of(BGS::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              end
            end

            it 'raises an exception' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
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
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end
          end
        end
      end

      context "when 'disabilities.secondaryDisabilities.approximateBeginDate' is present" do
        it 'raises an exception if date is invalid' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
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
                      approximateBeginDate: '2019-02-30'
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
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
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
                      approximateBeginDate: "#{Time.zone.now.year + 1}-01-01"
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

      context "when 'disabilities.secondaryDisabilities.classificationCode' is not present" do
        it 'raises an exception if name is not valid structure' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
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
              expect(response).to have_http_status(:bad_request)
            end
          end
        end

        it 'raises an exception if name is longer than 255 characters' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
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
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end
      end
    end

    describe "'disabilities' validations" do
      describe "'disabilities.classificationCode' validations" do
        [true, false].each do |flipped|
          context "when feature flag is #{flipped}" do
            before do
              allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return(flipped)
              allow(Flipper).to receive(:enabled?).with(:claims_api_526_validations_v1_local_bgs).and_return(flipped)
              if flipped
                allow_any_instance_of(ClaimsApi::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              else
                allow_any_instance_of(BGS::StandardDataService)
                  .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
              end
            end

            let(:classification_type_codes) { [{ clsfcn_id: '1111', end_dt: 1.year.from_now.iso8601 }] }

            context "when 'disabilities.classificationCode' is valid and expires in the future" do
              it 'returns a successful response' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end

            context "when 'disabilities.classificationCode' is valid but expires in the past" do
              before do
                if Flipper.enabled?(:claims_api_526_validations_v1_local_bgs)
                  allow_any_instance_of(ClaimsApi::StandardDataService)
                    .to receive(:get_contention_classification_type_code_list)
                    .and_return([{
                                  clsfcn_id: '1111',
                                  end_dt: 1.year.ago.iso8601
                                }])
                else
                  allow_any_instance_of(BGS::StandardDataService)
                    .to receive(:get_contention_classification_type_code_list)
                    .and_return([{
                                  clsfcn_id: '1111',
                                  end_dt: 1.year.ago.iso8601
                                }])
                end
              end

              it 'responds with a bad request' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api_bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end

            context "when 'disabilities.classificationCode' is invalid" do
              it 'responds with a bad request' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/brd/countries') do
                    VCR.use_cassette('claims_api/bgs/standard_service_data') do
                      json_data = JSON.parse data
                      params = json_data
                      disabilities = [
                        {
                          disabilityActionType: 'NEW',
                          name: 'PTSD (post traumatic stress disorder)',
                          classificationCode: '2222'
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response).to have_http_status(:bad_request)
                    end
                  end
                end
              end
            end
          end
        end
      end

      describe "'disabilities.ratedDisabilityId' validations" do
        context "when 'disabilities.disabilityActionType' equals 'INCREASE'" do
          context "and 'disabilities.ratedDisabilityId' is not provided" do
            it 'returns an unprocessable entity status' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    disabilities = [
                      {
                        diagnosticCode: 123,
                        ratedDisabilityId: '1100583',
                        disabilityActionType: 'INCREASE',
                        name: 'PTSD (post traumatic stress disorder)'
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
            it 'returns an unprocessable entity status' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
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

        context "when 'disabilities.disabilityActionType' equals 'NONE'" do
          context "and 'disabilities.secondaryDisabilities' is defined" do
            context "and 'disabilities.diagnosticCode is not provided" do
              it 'returns an unprocessable entity status' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/claims/claims') do
                    VCR.use_cassette('claims_api/brd/countries') do
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
                              serviceRelevance: 'Caused by a service-connected disability\\nLengthy description',
                              specialIssues: ['Radiation', 'Emergency Care – CH17 Determination']
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

        context "when 'disabilities.disabilityActionType' equals value other than 'INCREASE'" do
          context "and 'disabilities.ratedDisabilityId' is not provided" do
            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    disabilities = [
                      {
                        diagnosticCode: 123,
                        disabilityActionType: 'NEW',
                        name: 'PTSD (post traumatic stress disorder)'
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

      describe "'disabilities.approximateBeginDate' validations" do
        let(:disabilities) do
          [
            {
              disabilityActionType: 'NEW',
              name: 'PTSD (post traumatic stress disorder)',
              approximateBeginDate: approximate_begin_date
            }
          ]
        end

        context "when 'approximateBeginDate' is in the future" do
          let(:approximate_begin_date) { (Time.zone.today + 1.year).to_s }

          it 'responds with a bad request' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'] = disabilities
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end

        context "when 'approximateBeginDate' is in the past" do
          let(:approximate_begin_date) { (Time.zone.today - 1.year).to_s }

          it 'responds with a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  disabilities = [
                    {
                      diagnosticCode: 123,
                      disabilityActionType: 'NEW',
                      name: 'PTSD (post traumatic stress disorder)'
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

      describe "'disabilities.specialIssues' validations" do
        let(:disabilities) do
          [
            {
              disabilityActionType: 'NEW',
              name: disability_name,
              specialIssues: special_issues
            }
          ]
        end

        context "when 'specialIssues' includes 'HEPC'" do
          let(:special_issues) { %w[HEPC] }

          context "when 'disability.name' is not 'Hepatitis'" do
            let(:disability_name) { 'PTSD (post traumatic stress disorder)' }

            it 'responds with a bad request' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end

            it 'responds with a useful error message' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    errors = JSON.parse(response.body)['errors']
                    expected_verbiage = "Claim must include a disability with the name 'hepatitis'"
                    expect(errors.any? { |error| error['detail'].include?(expected_verbiage) }).to be true
                  end
                end
              end
            end
          end

          context "when 'disability.name' is 'Hepatitis'" do
            let(:disability_name) { 'Hepatitis' }

            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
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

        context "when 'specialIssues' includes 'POW'" do
          let(:special_issues) { %w[POW] }
          let(:disability_name) { 'PTSD (post traumatic stress disorder)' }

          context "when a valid 'confinements' is not included" do
            it 'responds with a bad request' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['serviceInformation'].delete('confinements')
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:bad_request)
                end
              end
            end

            it 'responds with a useful error message' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['serviceInformation'].delete('confinements')
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  errors = JSON.parse(response.body)['errors']
                  expected_verbiage = "Claim must include valid 'serviceInformation.confinements' value"
                  expect(errors.any? { |error| error['detail'].include?(expected_verbiage) }).to be true
                end
              end
            end
          end

          context "when a valid 'confinements' is included" do
            let(:confinements) do
              [
                {
                  confinementBeginDate: '1981-01-01',
                  confinementEndDate: '1982-01-01'
                }
              ]
            end

            it 'responds with a 200' do
              mock_acg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/claims/claims') do
                  VCR.use_cassette('claims_api/brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['disabilities'] = disabilities
                    params['data']['attributes']['serviceInformation']['confinements'] = confinements
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end
        end

        context "when no 'specialIssues' are provided" do
          let(:disabilities) do
            [
              {
                disabilityActionType: 'NEW',
                name: 'Hepatitis',
                specialIssues: []
              }
            ]
          end

          it "passes 'special_issues' as an empty array to the constructor" do
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(
              hash_including(special_issues: [])
            )

            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                end
              end
            end
          end
        end

        context "when 'specialIssues' are provided for some 'disabilities'" do
          let(:disabilities) do
            [
              {
                disabilityActionType: 'NEW',
                name: 'Hepatitis',
                specialIssues: []
              },
              {
                disabilityActionType: 'NEW',
                name: 'Tinnitus',
                specialIssues: ['Asbestos']
              }
            ]
          end

          it "passes 'special_issues' an appropriate array to the constructor" do
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(
              hash_including(
                special_issues: [{ code: nil, name: 'Tinnitus', special_issues: ['ASB'] }]
              )
            )

            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                end
              end
            end
          end
        end
      end
    end

    describe "'currentMailingAddress' validations" do
      describe "'addressLine3'" do
        it "accepts 'addressLine3' and returns a 200" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['currentMailingAddress']['addressLine3'] = 'Box 123'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end
      end

      describe "'currentMailingAddress.country'" do
        it "accepts 'USA'" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['currentMailingAddress']['country'] = 'USA'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end

        it "does not accept 'US'" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['veteran']['currentMailingAddress']['country'] = 'US'
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:bad_request)
            end
          end
        end
      end
    end

    describe "'applicationExpirationDate'" do
      describe 'is optional' do
        context 'when not provided' do
          it 'responds with a 200' do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/claims/claims') do
                VCR.use_cassette('claims_api/brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes'].delete('applicationExpirationDate')
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end
        end
      end
    end

    describe "'directDeposit.accountType" do
      describe 'is case insensitive' do
        it 'is properly transformed to uppercase before submission to EVSS' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                direct_deposit_info = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                                      'form_526_direct_deposit.json').read
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['directDeposit'] = JSON.parse direct_deposit_info
                expect(params['data']['attributes']['directDeposit']['accountType']).to eq('Checking')

                post path, params: params.to_json, headers: headers.merge(auth_header)

                expect(response).to have_http_status(:ok)
                response_body = JSON.parse response.body
                claim_id = response_body['data']['id']
                claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)
                expect(claim.form_data['directDeposit']['accountType']).to eq('CHECKING')
              end
            end
          end
        end
      end
    end

    describe "'directDeposit.bankName" do
      it 'is required if any other directDeposit values are present' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims') do
            VCR.use_cassette('claims_api/brd/countries') do
              direct_deposit_info = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                                    'form_526_direct_deposit.json').read
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['directDeposit'] = JSON.parse direct_deposit_info
              params['data']['attributes']['directDeposit']['bankName'] = ''

              post path, params: params.to_json, headers: headers.merge(auth_header)

              expect(response).to have_http_status(:bad_request)
              errors = JSON.parse(response.body)['errors']
              expected_verbiage = '"" is not a valid value for "directDeposit.bankName"'
              expect(errors.any? { |error| error['detail'].include?(expected_verbiage) }).to be true
            end
          end
        end
      end
    end
  end

  describe '#526 without flashes or special issues' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data_no_flashes) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                             'form_526_no_flashes_no_special_issues.json').read
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json').read }

    it 'sets the flashes and special_issues' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          VCR.use_cassette('claims_api/brd/countries') do
            post path, params: data_no_flashes, headers: headers.merge(auth_header)
            token = JSON.parse(response.body)['data']['attributes']['token']
            aec = ClaimsApi::AutoEstablishedClaim.find(token)
            expect(aec.flashes).to eq(%w[])
            expect(aec.special_issues).to eq(%w[])
          end
        end
      end
    end
  end

  describe '#upload_documents' do
    let(:auto_claim) { create(:auto_established_claim) }
    let(:non_auto_claim) { create(:auto_established_claim, :autoCestPDFGeneration_disabled) }
    let(:binary_params) do
      { attachment1: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                     .split('/')).to_s),
        attachment2: Rack::Test::UploadedFile.new(Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                     .split('/')).to_s) }
    end

    let(:base64_params) do
      { attachment1: File.read(Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s),
        attachment2: File.read(Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s) }
    end

    context 'when no attachment is provided to the PUT endpoint' do
      it 'rejects the request for missing param' do
        mock_acg(scopes) do |auth_header|
          put("/services/claims/v1/forms/526/#{auto_claim.id}", headers: headers.merge(auth_header))
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'][0]['title']).to eq('Missing parameter')
          expect(response.parsed_body['errors'][0]['detail']).to eq('Must include attachment')
        end
      end
    end

    it 'upload 526 binary form through PUT' do
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: binary_params, headers: headers.merge(auth_header))
        expect(response).to have_http_status(:ok)
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'upload 526 base64 form through PUT' do
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: base64_params, headers: headers.merge(auth_header), as: :json)
        expect(response).to have_http_status(:ok)
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'rejects uploading 526 through PUT when autoCestPDFGenerationDisabled is false' do
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{non_auto_claim.id}",
            params: binary_params, headers: headers.merge(auth_header))
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'upload binary support docs and increases the supporting document count' do
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: binary_params, headers: headers.merge(auth_header))
        expect(response).to have_http_status(:ok)
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 2)
      end
    end

    it 'upload base64 support docs and increases the supporting document count' do
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: base64_params, headers: headers.merge(auth_header), as: :json)
        expect(response).to have_http_status(:ok)
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 2)
      end
    end

    it 'bad claim ID returns 404' do
      bad_id = 0
      mock_acg(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        post("/services/claims/v1/forms/526/#{bad_id}/attachments",
             params: binary_params, headers: headers.merge(auth_header))
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'support doc fails, should retry' do
      mock_acg(scopes) do |auth_header|
        body = {
          messages: [
            { key: '',
              severity: 'ERROR',
              text: 'Error calling external service to upload claim document.' }
          ]
        }

        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return false
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return(true)
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        allow_any_instance_of(ClaimsApi::BD).to(
          receive(:upload).and_raise(Common::Exceptions::BackendServiceException.new(
                                       '', {}, 500, body
                                     ))
        )
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: base64_params, headers: headers.merge(auth_header), as: :json)
        expect(response).to have_http_status(:ok)
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 2)
      end
    end

    context 'when a claim is already established' do
      let(:auto_claim) { create(:auto_established_claim, :established) }

      it 'returns a 404 error because only pending claims are allowed' do
        mock_acg(scopes) do |auth_header|
          allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
          put("/services/claims/v1/forms/526/#{auto_claim.id}",
              params: binary_params, headers: headers.merge(auth_header))
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST #submit_form_526 using md5 lookup' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }

    it 'returns existing claim if duplicate submit occurs by using the hashed lookup' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          VCR.use_cassette('claims_api/brd/countries') do
            json = JSON.parse(data)
            post path, params: json.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:ok)
            first_submit_parsed = JSON.parse(response.body)
            @original_id = first_submit_parsed['data']['id']
          end
        end
      end
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          VCR.use_cassette('claims_api/brd/countries') do
            json = JSON.parse(data)
            post path, params: json.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:ok)
            duplicate_submit_parsed = JSON.parse(response.body)
            duplicate_id = duplicate_submit_parsed['data']['id']
            expect(@original_id).to eq(duplicate_id)
          end
        end
      end
    end
  end
end
