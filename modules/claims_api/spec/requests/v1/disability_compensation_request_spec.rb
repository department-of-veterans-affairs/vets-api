# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }
  let(:multi_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: 'OK',
      profile: FactoryBot.build(:mpi_profile, participant_id: nil, participant_ids: %w[123456789 987654321])
    )
  end

  before do
    stub_poa_verification
    stub_mpi
    Timecop.freeze(Time.zone.now)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data) do
      temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json')) }
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(400)
              end
            end
          end
        end

        context "when 'treatment.startDate' is after earliest 'servicePeriods.activeDutyBeginDate'" do
          let(:treatment_start_date) { '1985-01-01' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end

        context "when 'treatment.startDate' is included but empty" do
          let(:treatment_start_date) { '' }

          it 'returns a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(400)
              end
            end
          end
        end

        context "when 'treatment.endDate' is after 'treatment.startDate'" do
          let(:treatment_end_date) { '1986-01-01' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                params['data']['attributes']['treatments'][0][:center][:country] = ''

                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
              end
            end
          end
        end

        context "when 'treatments[].center.country' is too long'" do
          let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)'] }

          it 'returns a bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                params['data']['attributes']['treatments'][0][:center][:country] =
                  'Here\'s a country that has a very very very long name'

                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
              end
            end
          end
        end

        context "when 'treatment.treatedDisabilityNames' includes value that does not match 'disability'" do
          let(:treated_disability_names) { ['not included in submitted disabilities collection'] }

          it 'returns a bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['treatments'] = treatments
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(400)
              end
            end
          end
        end

        context "when 'treatment.treatedDisabilityNames' includes value that does match 'disability'" do
          let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)'] }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['treatments'] = treatments

                  post path, params: params.to_json, headers: headers.merge(auth_header)

                  expect(response.status).to eq(200)
                end
              end
            end
          end

          context 'but has leading whitespace' do
            let(:treated_disability_names) { ['   PTSD (post traumatic stress disorder)'] }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end

          context 'but has trailing whitespace' do
            let(:treated_disability_names) { ['PTSD (post traumatic stress disorder)   '] }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end

          context 'but has different casing' do
            let(:treated_disability_names) { ['PtSd (PoSt TrAuMaTiC StReSs DiSoRdEr)'] }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['treatments'] = treatments
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
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
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
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
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
                post path, params: data, headers: headers.merge(auth_header)
              end
            end
          end
        end
      end

      context 'when autoCestPDFGenerationDisabled is true' do
        let(:auto_cest_pdf_generation_disabled) { true }

        it 'creates the sidekick job' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                post path, params: data, headers: headers.merge(auth_header)
              end
            end
          end
        end
      end

      it 'assigns a source' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.source).to eq('abraham lincoln')
            end
          end
        end
      end

      it "assigns a 'cid' (OKTA client_id)" do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              jwt_payload = {
                'ver' => 1,
                'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
                'iss' => 'https://example.com/oauth2/default',
                'aud' => 'api://default',
                'iat' => Time.current.utc.to_i,
                'exp' => Time.current.utc.to_i + 3600,
                'cid' => '0oa1c01m77heEXUZt2p7',
                'uid' => '00u1zlqhuo3yLa2Xs2p7',
                'scp' => %w[claim.write],
                'sub' => 'ae9ff5f4e4b741389904087d94cd19b2',
                'icn' => '1013062086V794840'
              }
              allow_any_instance_of(Token).to receive(:payload).and_return(jwt_payload)

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
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              token = JSON.parse(response.body)['data']['attributes']['token']
              aec = ClaimsApi::AutoEstablishedClaim.find(token)
              expect(aec.flashes).to eq(%w[Hardship Homeless])
            end
          end
        end
      end

      it 'sets the special issues' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
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
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              auth_header_stub = instance_double('EVSS::DisabilityCompensationAuthHeaders')
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
                  beginningDate: (Time.zone.now - 1.month).to_date.to_s,
                  endingDate: (Time.zone.now + 1.month).to_date.to_s,
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
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/intake_sites') do
                    VCR.use_cassette('brd/countries') do
                      par = json_data
                      par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address

                      post path, params: par.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(400)
                    end
                  end
                end
              end
            end
          end
        end

        context 'when an invalid country is submitted' do
          let(:change_of_address) do
            {
              beginningDate: (Time.zone.now + 1.month).to_date.to_s,
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/intake_sites') do
                VCR.use_cassette('brd/countries') do
                  par = json_data
                  par['data']['attributes']['veteran']['changeOfAddress'] = change_of_address

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end
          end
        end
      end

      context 'when reservesNationalGuardService information is submitted' do
        let(:json_data) { JSON.parse data }
        let(:title10_activation_date) { (Time.zone.now - 1.day).to_date.to_s }
        let(:anticipated_separation_date) { (Time.zone.now + 1.year).to_date.to_s }
        let(:reserves_national_guard_service) do
          {
            obligationTermOfServiceFromDate: (Time.zone.now - 1.year).to_date.to_s,
            obligationTermOfServiceToDate: (Time.zone.now - 6.months).to_date.to_s,
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

        context "'title10ActivationDate' validations" do
          context 'when title10ActivationDate is prior to earliest servicePeriod.activeDutyBeginDate' do
            let(:title10_activation_date) { '1980-02-04' }

            it 'raises an exception that title10ActivationDate is invalid' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(400)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is same day as earliest servicePeriod.activeDutyBeginDate' do
            let(:title10_activation_date) { '1980-02-05' }

            it 'raises an exception that title10ActivationDate is invalid' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end
          end

          context 'when title10ActivationDate is after earliest servicePeriod.activeDutyBeginDate but before today' do
            let(:title10_activation_date) { '1980-02-06' }

            it 'returns a successful response' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is today' do
            let(:title10_activation_date) { Time.zone.now.to_date.to_s }

            it 'returns a successful response' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end

          context 'when title10ActivationDate is tomorrow' do
            let(:title10_activation_date) { (Time.zone.now + 1.day).to_date.to_s }

            it 'raises an exception that title10ActivationDate is invalid' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end
          end
        end

        context "'anticipatedSeparationDate' validations" do
          context "when 'anticipatedSeparationDate' is in the past" do
            let(:anticipated_separation_date) { (Time.zone.now - 1.day).to_date.to_s }

            it "raises an exception that 'anticipatedSeparationDate' is invalid" do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(400)
                  end
                end
              end
            end
          end

          context "when 'anticipatedSeparationDate' is today" do
            let(:anticipated_separation_date) { (Time.zone.now - 1.hour).to_date.to_s }

            it "raises an exception that 'anticipatedSeparationDate' is invalid" do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  par = json_data
                  par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                    reserves_national_guard_service

                  post path, params: par.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end
          end

          context "when 'anticipatedSeparationDate' is in the future" do
            let(:anticipated_separation_date) { (Time.zone.now + 1.day).to_date.to_s }

            it 'returns a successful response' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    par = json_data
                    par['data']['attributes']['serviceInformation']['reservesNationalGuardService'] =
                      reserves_national_guard_service

                    post path, params: par.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
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
          with_okta_user(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['serviceInformation']['someBadField'] = 'someValue'
            params['data']['attributes']['anotherBadField'] = 'someValue'

            post path, params: params.to_json, headers: headers.merge(auth_header)

            expect(response.status).to eq(422)
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
          with_okta_user(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['veteran']['currentMailingAddress'] = {}
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
            expect(JSON.parse(response.body)['errors'].size).to eq(5)
          end
        end

        it 'requires homelessness currentlyHomeless subfields' do
          with_okta_user(scopes) do |auth_header|
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
            expect(response.status).to eq(422)
            expect(JSON.parse(response.body)['errors'].size).to eq(1)
          end
        end

        it 'requires homelessness homelessnessRisk subfields' do
          VCR.use_cassette('evss/claims/claims') do
            with_okta_user(scopes) do |auth_header|
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
              expect(response.status).to eq(422)
              expect(JSON.parse(response.body)['errors'].size).to eq(1)
            end
          end
        end

        it 'requires disability subfields' do
          with_okta_user(scopes) do |auth_header|
            params = json_data
            params['data']['attributes']['disabilities'] = [{}]
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
            expect(JSON.parse(response.body)['errors'].size).to eq(4)
          end
        end

        describe 'disabilities specialIssues' do
          context 'when an incorrect type is passed for specialIssues' do
            it 'returns errors explaining the failure' do
              with_okta_user(scopes) do |auth_header|
                params = json_data
                params['data']['attributes']['disabilities'][0]['specialIssues'] = ['invalidType']
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
                expect(JSON.parse(response.body)['errors'].size).to eq(1)
              end
            end
          end

          context 'when correct types are passed for specialIssues' do
            it 'returns a successful status' do
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  with_okta_user(scopes) do |auth_header|
                    params = json_data
                    params['data']['attributes']['disabilities'][0]['specialIssues'] = %w[ALS PTSD/1]
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end

        describe 'flashes' do
          context 'when an incorrect type is passed for flashes' do
            it 'returns errors explaining the failure' do
              with_okta_user(scopes) do |auth_header|
                params = json_data
                params['data']['attributes']['veteran']['flashes'] = ['invalidType']
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
                expect(JSON.parse(response.body)['errors'].size).to eq(1)
              end
            end
          end

          context 'when correct types are passed for flashes' do
            it 'returns a successful status' do
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  with_okta_user(scopes) do |auth_header|
                    params = json_data
                    params['data']['attributes']['veteran']['flashes'] = %w[Hardship POW]
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end

        it 'requires international postal code when address type is international' do
          with_okta_user(scopes) do |auth_header|
            params = json_data
            mailing_address = params['data']['attributes']['veteran']['currentMailingAddress']
            mailing_address['type'] = 'INTERNATIONAL'
            params['data']['attributes']['veteran']['currentMailingAddress'] = mailing_address

            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
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
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response.status).to eq 422
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
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  body = JSON.parse(response.body)
                  expect(response.status).to eq 422
                  expect(body['errors']).to be_an Array
                  expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object: #{json}"
                end
              end
            end
          end

          context 'request.body is a JSON integer' do
            let(:json) { '66' }

            it 'responds with a properly formed error object' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  body = JSON.parse(response.body)
                  expect(response.status).to eq 422
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
          VCR.use_cassette('evss/disability_compensation_form/form_526_valid_validation') do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('evss/claims/claims') do
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
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  parsed = JSON.parse(response.body)
                  expect(parsed['errors'].size).to eq(2)
                end
              end
            end
          end
        end

        it 'increment counters for statsd' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
              expect(StatsD).to receive(:increment).at_least(:once)
              post path, params: data, headers: headers.merge(auth_header)
            end
          end
        end

        it 'returns a list of errors when invalid via internal validation' do
          with_okta_user(scopes) do |auth_header|
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['veteran']['currentMailingAddress'] = {}
            post path, params: params.to_json, headers: headers.merge(auth_header)
            parsed = JSON.parse(response.body)
            expect(response.status).to eq(422)
            expect(parsed['errors'].size).to eq(5)
          end
        end

        context 'Breakers outages are recorded (investigating)' do
          it 'is logged to PersonalInformationLog' do
            EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service.begin_forced_outage!
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('evss/claims/claims') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(PersonalInformationLog.count).to be_positive
                  expect(PersonalInformationLog.last.error_class).to eq('validate_form_526 Breakers::OutageException')
                end
              end
            end
            EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service.end_forced_outage!
          end
        end

        context 'Timeouts are recorded (investigating)' do
          [Common::Exceptions::GatewayTimeout, Timeout::Error, Faraday::TimeoutError].each do |error_klass|
            context error_klass.to_s do
              it 'is logged to PersonalInformationLog' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    VCR.use_cassette('evss/claims/claims') do
                      allow_any_instance_of(ClaimsApi::DisabilityCompensation::MockOverrideService)
                        .to receive(:validate_form526).and_raise(error_klass)
                      allow_any_instance_of(EVSS::DisabilityCompensationForm::Service)
                        .to receive(:validate_form526).and_raise(error_klass)
                      post path, params: data, headers: headers.merge(auth_header)
                      expect(PersonalInformationLog.count).to be_positive
                      expect(PersonalInformationLog.last.error_class).to eq("validate_form_526 #{error_klass.name}")
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    context 'when Veteran is missing a participant_id' do
      before do
        stub_mpi_not_found
      end

      context 'when consumer is representative' do
        it 'returns an unprocessible entity status' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response.status).to eq(422)
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
            profile: FactoryBot.build(:mpi_profile, edipi: '2536798')
          )
        end
        let(:profile) { build(:mpi_profile) }
        let(:mpi_profile_response) { build(:find_profile_response, profile:) }

        it 'returns a 422 without an edipi' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('mpi/add_person/add_person_success') do
                  VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes') do
                    expect_any_instance_of(MPIData).to receive(:add_person_proxy).once.and_call_original
                    expect_any_instance_of(MPI::Service).to receive(:add_person_proxy).and_return(add_response)
                    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
                      .and_return(mpi_profile_response)
                    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes_with_orch_search)
                      .and_return(mpi_profile_response)

                    post path, params: data, headers: auth_header

                    expect(response.status).to eq(422)
                  end
                end
              end
            end
          end
        end

        it 'adds person to MPI and checks for edipi' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                VCR.use_cassette('mpi/add_person/add_person_success') do
                  VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes') do
                    allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(true)
                    allow_any_instance_of(MPIData).to receive(:mvi_response)
                      .and_return(profile_with_edipi)

                    post path, params: data, headers: auth_header
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end
      end

      context 'when consumer is Veteran, but is missing a participant id' do
        let(:profile) { build(:mpi_profile) }
        let(:mpi_profile_response) { build(:find_profile_response, profile:) }

        it 'raises a 422, with message' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                mpi_profile_response.profile.participant_ids = []
                mpi_profile_response.profile.participant_id = ''
                allow_any_instance_of(MPIData).to receive(:add_person_proxy)
                  .and_return(mpi_profile_response)

                post path, params: data, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(422)
                expect(json_response['errors'][0]['detail']).to eq(
                  'Veteran missing Participant ID. ' \
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
          stub_mpi(build(:mpi_profile, birls_id: nil))
        end

        it 'returns an unprocessible entity status' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('brd/countries') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(response.status).to eq(422)
            end
          end
        end
      end
    end

    context 'when Veteran has multiple participant_ids' do
      before do
        stub_mpi(build(:mpi_profile, birls_id: nil))
      end

      it 'returns an unprocessible entity status' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('brd/countries') do
            VCR.use_cassette('evss/claims/claims') do
              allow_any_instance_of(ClaimsApi::Veteran)
                .to receive(:mpi_record?).and_return(true)
              allow_any_instance_of(MPIData)
                .to receive(:mvi_response).and_return(multi_profile)
              allow_any_instance_of(MPIData)
                .to receive(:add_person_proxy).and_return(add_response)

              post path, params: data, headers: headers.merge(auth_header)
              data = JSON.parse(response.body)
              expect(response.status).to eq(422)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
                  expect(response.status).to eq(200)
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
                expect(response.status).to eq(400)
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end

        context "and 'claim_date' is in the future" do
          let(:claim_date) { (Time.zone.today + 1.day).to_s }

          it 'responds with bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response.status).to eq(400)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (iso w/Z)" do
          let(:claim_date) { (Time.zone.now - 1.day).iso8601 }

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end

        context "and 'claim_date' has timezone (iso wo/Z)" do
          let(:claim_date) { (Time.zone.now - 1.day).iso8601.sub('Z', '-00:00') }

          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end

        context "and 'claim_date' has timezone (iso w/out zone)" do
          let(:claim_date) { (Time.zone.now - 1.day).iso8601.sub('Z', '') }

          it 'responds with a bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (TZ String)" do
          let(:claim_date) { (Time.zone.now - 1.day).to_s }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
              end
            end
          end
        end

        context "and 'claim_date' has timezone (w/out T)" do
          let(:claim_date) { (Time.zone.now - 1.day).iso8601.sub('T', ' ') }

          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                post path, params: data, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
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
                expect(response.status).to eq(422)
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
                expect(response.status).to eq(422)
              end
            end
          end
        end
      end
    end

    context 'when submitted application_expiration_date is in the past' do
      it 'responds with bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['applicationExpirationDate'] = (Time.zone.today - 1.day).to_s
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when submitted application_expiration_date is today' do
      it 'responds with bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('brd/countries') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['applicationExpirationDate'] = Time.zone.today.to_s
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when submitted application_expiration_date is in the future' do
      it 'responds with a 200' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(200)
            end
          end
        end
      end
    end

    context 'when submitted claimant_certification is false' do
      it 'responds with bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['claimantCertification'] = false
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when submitted separationLocationCode is missing for a future activeDutyEndDate' do
      it 'responds with bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('brd/intake_sites') do
            VCR.use_cassette('brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['serviceInformation']['servicePeriods'].first['activeDutyEndDate'] =
                (Time.zone.today + 10.days).to_s
              post path, params: params.to_json, headers: headers.merge(auth_header)
              json = JSON.parse(response.body)
              expect(response.status).to eq(400)
              expect(json['errors'][0]['title']).to eq('Invalid field value')
            end
          end
        end
      end
    end

    context 'when submitted separationLocationCode is invalid' do
      it 'responds with bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('brd/intake_sites') do
            json_data = JSON.parse data
            params = json_data
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['activeDutyEndDate'] =
              (Time.zone.today + 1.day).to_s
            params['data']['attributes']['serviceInformation']['servicePeriods'].first['separationLocationCode'] =
              '11111111111'
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when confinements don\'t fall within service periods' do
      it 'responds with a bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims') do
            VCR.use_cassette('brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['serviceInformation']['confinements'] = [{
                confinementBeginDate: (Time.zone.today - 2.weeks).to_s,
                confinementEndDate: (Time.zone.today + 1.week).to_s
              }]
              post path, params: params.to_json, headers: headers.merge(auth_header)
              response_error_details = JSON.parse(response.body)['errors'].first['detail']
              expect(response.status).to eq(400)
              expect(response_error_details).to include('confinements must be within a service period')
            end
          end
        end
      end
    end

    context 'when confinements are overlapping' do
      it 'responds with a bad request' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('brd/countries') do
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
            expect(response.status).to eq(400)
            expect(response_error_details).to include('confinements must not overlap other confinements')
          end
        end
      end
    end

    describe 'Veteran homelessness validations' do
      context "when 'currentlyHomeless' and 'homelessnessRisk' are both provided" do
        it 'responds with a 422' do
          with_okta_user(scopes) do |auth_header|
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
            expect(response.status).to eq(422)
            response_body = JSON.parse(response.body)
            expect(response_body['errors'].length).to eq(1)
            expect(response_body['errors'][0]['detail']).to eq(
              "Must define only one of 'veteran.homelessness.currentlyHomeless' or "\
              "'veteran.homelessness.homelessnessRisk'"
            )
          end
        end
      end

      context "when neither 'currentlyHomeless' nor 'homelessnessRisk' is provided" do
        context "when 'pointOfContact' is provided" do
          it 'responds with a 422' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
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
                  expect(response.status).to eq(422)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'].length).to eq(1)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If 'veteran.homelessness.pointOfContact' is defined, then one of "\
                    "'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk'"\
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
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['homelessness']['currentlyHomeless'] = {
                  homelessSituationType: 'fleeing',
                  otherLivingSituation: 'community help center'
                }
                params['data']['attributes']['veteran']['homelessness'].delete('pointOfContact')
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(422)
                response_body = JSON.parse(response.body)
                expect(response_body['errors'].length).to eq(1)
                expect(response_body['errors'][0]['detail']).to eq(
                  "If one of 'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk' is"\
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
              'militaryRetiredPay': {
                'receiving': receiving,
                'willReceiveInFuture': will_receive,
                'futurePayExplanation': 'Some explanation',
                'payment': {
                  'serviceBranch': 'Air Force'
                }
              }
            }
          end

          context "when 'receiving' and 'willReceiveInFuture' are equal but not 'nil'" do
            context "when both are 'true'" do
              let(:receiving) { true }
              let(:will_receive) { true }

              before do
                stub_mpi
              end

              it 'responds with a bad request' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(400)
                    end
                  end
                end
              end
            end

            context "when both are 'false'" do
              let(:receiving) { false }
              let(:will_receive) { false }

              before do
                stub_mpi
              end

              it 'responds with a bad request' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(400)
                  end
                end
              end
            end
          end

          context "when 'receiving' and 'willReceiveInFuture' are not equal" do
            context "when 'receiving' is 'false' and 'willReceiveInFuture' is 'true'" do
              let(:receiving) { false }
              let(:will_receive) { true }

              before do
                stub_mpi
              end

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(200)
                    end
                  end
                end
              end
            end

            context "when 'receiving' is 'true' and 'willReceiveInFuture' is 'false'" do
              let(:receiving) { true }
              let(:will_receive) { false }

              before do
                stub_mpi
              end

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(200)
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
              'militaryRetiredPay': {
                'receiving': true,
                'willReceiveInFuture': false,
                'payment': {
                  'serviceBranch': 'Air Force',
                  'amount': military_retired_payment_amount
                }
              }
            }
          end

          context "when 'amount' is below the minimum" do
            let(:military_retired_payment_amount) { 0 }

            before do
              stub_mpi
            end

            it 'responds with an unprocessible entity' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(422)
                end
              end
            end
          end

          context "when 'amount' is above the maximum" do
            let(:military_retired_payment_amount) { 1_000_000 }

            before do
              stub_mpi
            end

            it 'responds with an unprocessible entity' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(422)
                  end
                end
              end
            end
          end

          context "when 'amount' is within limits" do
            let(:military_retired_payment_amount) { 100 }

            before do
              stub_mpi
            end

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
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
                  'militaryRetiredPay': {
                    'receiving': false,
                    'willReceiveInFuture': will_receive_in_future,
                    'payment': {
                      'serviceBranch': 'Air Force'
                    }
                  }
                }
              end

              before do
                stub_mpi
              end

              it 'responds with an unprocessible entity' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(422)
                  end
                end
              end
            end

            context "when 'militaryRetiredPay.futurePayExplanation' is provided" do
              let(:service_pay_attribute) do
                {
                  'militaryRetiredPay': {
                    'receiving': false,
                    'willReceiveInFuture': will_receive_in_future,
                    'futurePayExplanation': 'Retiring soon.',
                    'payment': {
                      'serviceBranch': 'Air Force'
                    }
                  }
                }
              end

              before do
                stub_mpi
              end

              it 'responds with a 200' do
                with_okta_user(scopes) do |auth_header|
                  VCR.use_cassette('evss/claims/claims') do
                    VCR.use_cassette('brd/countries') do
                      json_data = JSON.parse data
                      params = json_data
                      params['data']['attributes']['servicePay'] = service_pay_attribute
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(200)
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
              'separationPay': {
                'received': true,
                'receivedDate': (Time.zone.today - 1.year).to_s,
                'payment': {
                  'serviceBranch': 'Air Force',
                  'amount': separation_payment_amount
                }
              }
            }
          end

          context "when 'amount' is below the minimum" do
            let(:separation_payment_amount) { 0 }

            before do
              stub_mpi
            end

            it 'responds with an unprocessible entity' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(422)
                end
              end
            end
          end

          context "when 'amount' is above the maximum" do
            let(:separation_payment_amount) { 1_000_000 }

            before do
              stub_mpi
            end

            it 'responds with an unprocessible entity' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(422)
                  end
                end
              end
            end
          end

          context "when 'amount' is within limits" do
            let(:separation_payment_amount) { 100 }

            before do
              stub_mpi
            end

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end

        describe "'receivedDate'" do
          let(:service_pay_attribute) do
            {
              'separationPay': {
                'received': true,
                'receivedDate': received_date,
                'payment': {
                  'serviceBranch': 'Air Force',
                  'amount': 100
                }
              }
            }
          end

          context "when 'receivedDate' is not in the past" do
            let(:received_date) { Time.zone.today.to_s }

            before do
              stub_mpi
            end

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['servicePay'] = service_pay_attribute
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end
          end

          context "when 'receivedDate' is in the past" do
            let(:received_date) { (Time.zone.today - 1.year).to_s }

            before do
              stub_mpi
            end

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['servicePay'] = service_pay_attribute
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end
      end
    end

    describe "'disabilities.secondaryDisabilities' validations" do
      before do
        stub_mpi
      end

      context 'when disabilityActionType is NONE without secondaryDisabilities' do
        it 'raises an exception' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('brd/countries') do
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
              expect(response.status).to eq(400)
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
              expect(response.status).to eq(422)
            end
          end
        end
      end

      context "when 'disabilites.secondaryDisabilities.classificationCode' is invalid" do
        let(:classification_type_codes) { [{ clsfcn_id: '1111' }] }

        before do
          expect_any_instance_of(BGS::StandardDataService)
            .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
        end

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
              expect(response.status).to eq(400)
            end
          end
        end
      end

      context "when 'disabilites.secondaryDisabilities.classificationCode' does not match name" do
        let(:classification_type_codes) { [{ clsfcn_id: '1111' }] }

        before do
          expect_any_instance_of(BGS::StandardDataService)
            .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
        end

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
              expect(response.status).to eq(400)
            end
          end
        end
      end

      context "when 'disabilites.secondaryDisabilities.approximateBeginDate' is present" do
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
                      approximateBeginDate: '2019-02-30'
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(400)
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
                      approximateBeginDate: "#{Time.zone.now.year + 1}-01-01"
                    }
                  ]
                }
              ]
              params['data']['attributes']['disabilities'] = disabilities
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(400)
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
              expect(response.status).to eq(400)
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
                expect(response.status).to eq(400)
              end
            end
          end
        end
      end
    end

    describe "'disabilites' validations" do
      describe "'disabilities.classificationCode' validations" do
        let(:classification_type_codes) { [{ clsfcn_id: '1111' }] }

        before do
          stub_mpi

          expect_any_instance_of(BGS::StandardDataService)
            .to receive(:get_contention_classification_type_code_list).and_return(classification_type_codes)
        end

        context "when 'disabilites.classificationCode' is valid" do
          it 'returns a successful response' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
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
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end

        context "when 'disabilites.classificationCode' is invalid" do
          it 'responds with a bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
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
                expect(response.status).to eq(400)
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
                    expect(response.status).to eq(422)
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
                        name: 'PTSD (post traumatic stress disorder)'
                      }
                    ]
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
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
                  expect(response.status).to eq(422)
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
                              serviceRelevance: 'Caused by a service-connected disability\\nLengthy description',
                              specialIssues: ['Radiation', 'Emergency Care – CH17 Determination']
                            }
                          ]
                        }
                      ]
                      params['data']['attributes']['disabilities'] = disabilities
                      post path, params: params.to_json, headers: headers.merge(auth_header)
                      expect(response.status).to eq(422)
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
                        name: 'PTSD (post traumatic stress disorder)'
                      }
                    ]
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end
        end
      end

      describe "'disabilites.approximateBeginDate' validations" do
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

          before do
            stub_mpi
          end

          it 'responds with a bad request' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['disabilities'] = disabilities
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(400)
              end
            end
          end
        end

        context "when 'approximateBeginDate' is in the past" do
          let(:approximate_begin_date) { (Time.zone.today - 1.year).to_s }

          before do
            stub_mpi
          end

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
                      name: 'PTSD (post traumatic stress disorder)'
                    }
                  ]
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
                end
              end
            end
          end
        end
      end

      describe "'disabilites.specialIssues' validations" do
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

            before do
              stub_mpi
            end

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end

            it 'responds with a useful error message  ' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
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

            before do
              stub_mpi
            end

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['disabilities'] = disabilities
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
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
            before do
              stub_mpi
            end

            it 'responds with a bad request' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  params['data']['attributes']['serviceInformation'].delete('confinements')
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(400)
                end
              end
            end

            it 'responds with a useful error message ' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('brd/countries') do
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

            before do
              stub_mpi
            end

            it 'responds with a 200' do
              with_okta_user(scopes) do |auth_header|
                VCR.use_cassette('evss/claims/claims') do
                  VCR.use_cassette('brd/countries') do
                    json_data = JSON.parse data
                    params = json_data
                    params['data']['attributes']['disabilities'] = disabilities
                    params['data']['attributes']['serviceInformation']['confinements'] = confinements
                    post path, params: params.to_json, headers: headers.merge(auth_header)
                    expect(response.status).to eq(200)
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

          before do
            stub_mpi
          end

          it "passes 'special_issues' as an empty array to the constructor" do
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(
              hash_including(special_issues: [])
            )

            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes']['disabilities'] = disabilities
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                end
              end
            end
          end
        end

        context "when 'specialIssues' are provided for some 'disabilites'" do
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

          before do
            stub_mpi
          end

          it "passes 'special_issues' an appropriate array to the constructor" do
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(
              hash_including(
                special_issues: [{ code: nil, name: 'Tinnitus', special_issues: ['ASB'] }]
              )
            )

            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
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
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['currentMailingAddress']['addressLine3'] = 'Box 123'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(200)
              end
            end
          end
        end
      end

      describe "'currentMailingAddress.country'" do
        it "accepts 'USA'" do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['veteran']['currentMailingAddress']['country'] = 'USA'
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(200)
              end
            end
          end
        end

        it "does not accept 'US'" do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('brd/countries') do
              json_data = JSON.parse data
              params = json_data
              params['data']['attributes']['veteran']['currentMailingAddress']['country'] = 'US'
              post path, params: params.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(400)
            end
          end
        end
      end
    end

    describe "'applicationExpirationDate'" do
      describe 'is optional' do
        context 'when not provided' do
          it 'responds with a 200' do
            with_okta_user(scopes) do |auth_header|
              VCR.use_cassette('evss/claims/claims') do
                VCR.use_cassette('brd/countries') do
                  json_data = JSON.parse data
                  params = json_data
                  params['data']['attributes'].delete('applicationExpirationDate')
                  post path, params: params.to_json, headers: headers.merge(auth_header)
                  expect(response.status).to eq(200)
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
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              VCR.use_cassette('brd/countries') do
                direct_deposit_info = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                                                'form_526_direct_deposit.json'))
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['directDeposit'] = JSON.parse direct_deposit_info
                expect(params['data']['attributes']['directDeposit']['accountType']).to eq('Checking')

                post path, params: params.to_json, headers: headers.merge(auth_header)

                expect(response.status).to eq(200)
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
  end

  describe '#526 without flashes or special issues' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data_no_flashes) do
      temp = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures',
                                       'form_526_no_flashes_no_special_issues.json'))
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json')) }

    it 'sets the flashes and special_issues' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('brd/countries') do
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
      { attachment1: Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                     .split('/')).to_s),
        attachment2: Rack::Test::UploadedFile.new(::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'
                                                                     .split('/')).to_s) }
    end

    let(:base64_params) do
      { attachment1: File.read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s),
        attachment2: File.read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s) }
    end

    context 'when no attachment is provided to the PUT endpoint' do
      it 'rejects the request for missing param' do
        with_okta_user(scopes) do |auth_header|
          put("/services/claims/v1/forms/526/#{auto_claim.id}", headers: headers.merge(auth_header))
          expect(response.status).to eq(400)
          expect(response.parsed_body['errors'][0]['title']).to eq('Missing parameter')
          expect(response.parsed_body['errors'][0]['detail']).to eq('Must include attachment')
        end
      end
    end

    it 'upload 526 binary form through PUT' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: binary_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(200)
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'upload 526 base64 form through PUT' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: base64_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(200)
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'rejects uploading 526 through PUT when autoCestPDFGenerationDisabled is false' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{non_auto_claim.id}",
            params: binary_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(422)
      end
    end

    it 'upload binary support docs and increases the supporting document count' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: binary_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(200)
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 2)
      end
    end

    it 'upload base64 support docs and increases the supporting document count' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: base64_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(200)
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 2)
      end
    end

    it 'bad claim ID returns 404' do
      bad_id = 0
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        post("/services/claims/v1/forms/526/#{bad_id}/attachments",
             params: binary_params, headers: headers.merge(auth_header))
        expect(response.status).to eq(404)
      end
    end

    context 'when a claim is already established' do
      let(:auto_claim) { create(:auto_established_claim, :status_established) }

      it 'returns a 404 error because only pending claims are allowed' do
        with_okta_user(scopes) do |auth_header|
          allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
          put("/services/claims/v1/forms/526/#{auto_claim.id}",
              params: binary_params, headers: headers.merge(auth_header))
          expect(response.status).to eq(404)
        end
      end
    end
  end
end
