# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/intent_to_file_web_service'

RSpec.describe 'ClaimsApi::V1::Forms::0966', type: :request do
  let(:headers) do
    { 'Content-Type': 'application/json',
      'X-VA-SSN': '796-10-4437',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }
  let(:path) { '/services/claims/v1/forms/0966' }
  let(:data) { { data: { attributes: { type: 'compensation' } } } }
  let(:extra) do
    { type: 'compensation',
      participant_claimant_id: '123_456_789',
      received_date: '2015-01-05T17:42:12.058Z' }
  end
  let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '0966.json').read }

  before do
    stub_poa_verification
  end

  describe '#0966' do
    context 'when Veteran has all necessary identifiers' do
      describe 'schema' do
        it 'returns a successful get response with json schema' do
          get path
          json_schema = JSON.parse(response.body)['data'][0]
          expect(json_schema).to eq(JSON.parse(schema))
        end
      end

      it 'posts a minimum payload and returns a payload with an expiration date' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
          end
        end
      end

      it 'posts a maximum payload and returns a payload with an expiration date' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
            data[:data][:attributes] = extra
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
          end
        end
      end

      it 'posts a 404 error with detail when BGS returns a 500 response' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file_500') do
            data[:data][:attributes] = { type: 'pension' }
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      describe "'burial' submission" do
        it "returns a 403 when veteran is submitting for 'burial'" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:data][:attributes] = { type: 'burial' }
              post path, params: data.to_json, headers: auth_header
              expect(response).to have_http_status(:forbidden)
            end
          end
        end

        it "returns a 403 when neither 'participant_claimant_id' nor 'claimant_ssn' are provided" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:data][:attributes] = { type: 'burial' }
              post path, params: data.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:forbidden)
            end
          end
        end

        it "returns a 200 if the veteran is not the submitter and 'participant_claimant_id' is provided" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:attributes] = extra
              data[:attributes][:type] = 'burial'
              post path, params: data.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:ok)
            end
          end
        end

        it "returns a 200 if the veteran is not the submitter and 'claimant_ssn' is provided" do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:data][:attributes][:type] = 'burial'
              data[:data][:attributes][:claimant_ssn] = '123_456_789'
              post path, params: data.to_json, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      it "fails if passed a type that doesn't exist" do
        mock_acg(scopes) do |auth_header|
          data[:data][:attributes][:type] = 'failingtesttype'
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it 'fails if none is passed in' do
        mock_acg(scopes) do |auth_header|
          post path, headers: headers.merge(auth_header)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it 'fails if none is passed in as non-poa request' do
        mock_acg(scopes) do |auth_header|
          post path, headers: auth_header, params: ''
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it 'fails if any additional fields are passed in' do
        mock_acg(scopes) do |auth_header|
          data[:data][:attributes]['someBadField'] = 'someValue'

          post path, params: data.to_json, headers: headers.merge(auth_header)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].size).to eq(1)
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'The property /someBadField is not defined on the schema. Additional properties are not allowed'
          )
        end
      end

      describe 'handling the claimant fields' do
        context "when 'participant_claimant_id' is provided" do
          it 'that field and value are sent to BGS' do
            expect_any_instance_of(ClaimsApi::IntentToFileWebService)
              .to receive(:insert_intent_to_file).with(hash_including(participant_claimant_id: '123')).and_return({})

            mock_acg(scopes) do |auth_header|
              data[:data][:attributes][:participant_claimant_id] = '123'
              post path, params: data.to_json, headers: headers.merge(auth_header)
            end
          end
        end

        context "when 'claimant_ssn' is provided" do
          it 'that field and value are sent to BGS' do
            expect_any_instance_of(ClaimsApi::IntentToFileWebService)
              .to receive(:insert_intent_to_file).with(hash_including(claimant_ssn: '123')).and_return({})

            mock_acg(scopes) do |auth_header|
              data[:data][:attributes][:claimant_ssn] = '123'
              post path, params: data.to_json, headers: headers.merge(auth_header)
            end
          end
        end

        context "when neither 'participant_claimant_id' or 'claimant_ssn' is provided" do
          before do
            stub_mpi(build(:mpi_profile, participant_id: '999'))
          end

          it "'participant_claimant_id' is set to the target_veteran.participant_id and sent to BGS" do
            expect_any_instance_of(ClaimsApi::IntentToFileWebService)
              .to receive(:insert_intent_to_file).with(hash_including(participant_claimant_id: '999')).and_return({})

            mock_acg(scopes) do |auth_header|
              post path, params: data.to_json, headers: headers.merge(auth_header)
            end
          end
        end

        context "when both 'participant_claimant_id' and 'claimant_ssn' are provided" do
          it "both 'participant_claimant_id' and 'claimant_ssn' are sent to BGS" do
            expect_any_instance_of(ClaimsApi::IntentToFileWebService)
              .to receive(:insert_intent_to_file).with(
                hash_including(
                  participant_claimant_id: '123', claimant_ssn: '456'
                )
              ).and_return({})

            mock_acg(scopes) do |auth_header|
              data[:data][:attributes][:participant_claimant_id] = '123'
              data[:data][:attributes][:claimant_ssn] = '456'
              post path, params: data.to_json, headers: headers.merge(auth_header)
            end
          end
        end
      end

      describe 'creating a record for reporting purposes' do
        context 'when submitting the ITF to BGS is successful' do
          it "adds a 'ClaimsApi::IntentToFile' record" do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
                expect do
                  post path, params: data.to_json, headers: headers.merge(auth_header)
                end.to change(ClaimsApi::IntentToFile, :count).by(1)
                expect(ClaimsApi::IntentToFile.last.status).to eq(ClaimsApi::IntentToFile::SUBMITTED)
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end

        context 'when submitting the ITF to BGS is NOT successful' do
          it "adds a 'ClaimsApi::IntentToFile' record" do
            mock_acg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file_500') do
                data[:data][:attributes] = { type: 'pension' }
                expect do
                  post path, params: data.to_json, headers: headers.merge(auth_header)
                end.to change(ClaimsApi::IntentToFile, :count).by(1)
                expect(ClaimsApi::IntentToFile.last.status).to eq(ClaimsApi::IntentToFile::ERRORED)
                expect(response).to have_http_status(:not_found)
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
          mock_acg(scopes) do |auth_header|
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
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
          mock_acg(scopes) do |auth_header|
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end

  describe '#active' do
    before do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    end

    after do
      Timecop.return
    end

    it 'returns the latest itf of a compensation type' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'compensation' }, headers: headers.merge(auth_header)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a pension type' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'pension' }, headers: headers.merge(auth_header)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a burial type' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'burial' }, headers: headers.merge(auth_header)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'fails if passed with wrong type' do
      mock_acg(scopes) do |auth_header|
        get "#{path}/active", params: { type: 'test' }, headers: headers.merge(auth_header)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'fails if none is passed in for poa request' do
      mock_acg(scopes) do |auth_header|
        get "#{path}/active", headers: headers.merge(auth_header)
        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'fails if none is passed in for non-poa request' do
      mock_acg(scopes) do |auth_header|
        get "#{path}/active", headers: auth_header, params: ''
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe '#validate' do
    it 'returns a response when valid' do
      mock_acg(scopes) do |auth_header|
        post "#{path}/validate", params: data.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('intentToFileValidation')
      end
    end

    it 'returns a response when invalid' do
      mock_acg(scopes) do |auth_header|
        post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).not_to be_empty
      end
    end

    it 'responds properly when JSON parse error' do
      mock_acg(scopes) do |auth_header|
        post "#{path}/validate", params: 'hello', headers: headers.merge(auth_header)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'returns a 422 when invalid target_veteran' do
      mock_acg(scopes) do |auth_header|
        vet = build(:claims_veteran, :nil_birls_id)
        allow_any_instance_of(ClaimsApi::V1::ApplicationController)
          .to receive(:veteran_from_headers).and_return(vet)

        post "#{path}/validate", params: data.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['detail']).to eq("Unable to locate Veteran's BIRLS ID in Master Person Index " \
                                                    '(MPI). ' \
                                                    'Please submit an issue at ask.va.gov or call 1-800-MyVA411 ' \
                                                    '(800-698-2411) for assistance.')
      end
    end
  end
end
