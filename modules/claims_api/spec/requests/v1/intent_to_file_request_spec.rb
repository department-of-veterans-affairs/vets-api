# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Intent to file', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-10-4437',
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
      participant_claimant_id: 123_456_789,
      received_date: '2015-01-05T17:42:12.058Z' }
  end
  let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '0966.json')) }

  before do
    stub_poa_verification
  end

  describe '#0966' do
    context 'when Veteran has all necessary identifiers' do
      before do
        stub_mpi
      end

      describe 'schema' do
        it 'returns a successful get response with json schema' do
          get path
          json_schema = JSON.parse(response.body)['data'][0]
          expect(json_schema).to eq(JSON.parse(schema))
        end
      end

      it 'posts a minimum payload and returns a payload with an expiration date' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
          end
        end
      end

      it 'posts a maximum payload and returns a payload with an expiration date' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
            data['attributes'] = extra
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
          end
        end
      end

      it 'posts a 422 error with detail when BGS returns a 500 response' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file_500') do
            data[:data][:attributes] = { type: 'pension' }
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
          end
        end
      end

      describe "'burial' submission" do
        it "returns a 403 when veteran is submitting for 'burial'" do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:data][:attributes] = { type: 'burial' }
              post path, params: data.to_json, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end

        it "returns a 403 when 'participant claimant id' is not provided" do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:data][:attributes] = { type: 'burial' }
              post path, params: data.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(403)
            end
          end
        end

        it "returns a 200 if the veteran is not the submitter and 'participant claimant id' is provided" do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
              data[:attributes] = extra
              data[:attributes][:type] = 'burial'
              post path, params: data.to_json, headers: headers.merge(auth_header)
              expect(response.status).to eq(200)
            end
          end
        end
      end

      it "fails if passed a type that doesn't exist" do
        with_okta_user(scopes) do |auth_header|
          data[:data][:attributes][:type] = 'failingtesttype'
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
        end
      end

      it 'fails if none is passed in' do
        with_okta_user(scopes) do |auth_header|
          post path, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
        end
      end

      it 'fails if none is passed in as non-poa request' do
        with_okta_user(scopes) do |auth_header|
          post path, headers: auth_header, params: ''
          expect(response.status).to eq(422)
        end
      end

      it 'fails if any additional fields are passed in' do
        with_okta_user(scopes) do |auth_header|
          data[:data][:attributes]['someBadField'] = 'someValue'

          post path, params: data.to_json, headers: headers.merge(auth_header)

          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors'].size).to eq(1)
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'The property /someBadField is not defined on the schema. Additional properties are not allowed'
          )
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
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
          end
        end
      end

      context 'when consumer is Veteran' do
        it 'adds person to MPI' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
              VCR.use_cassette('mpi/add_person/add_person_success') do
                VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes') do
                  expect_any_instance_of(MPIData).to receive(:add_person).once.and_call_original
                  post path, params: data.to_json, headers: auth_header
                end
              end
            end
          end
        end
      end
    end

    context 'when Veteran has participant_id' do
      context 'when Veteran is missing a birls_id' do
        before do
          stub_mpi(build(:mvi_profile, birls_id: nil))
        end

        it 'returns an unprocessible entity status' do
          with_okta_user(scopes) do |auth_header|
            post path, params: data.to_json, headers: headers.merge(auth_header)
            expect(response.status).to eq(422)
          end
        end
      end
    end
  end

  describe '#active' do
    before do
      stub_mpi
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    end

    after do
      Timecop.return
    end

    it 'returns the latest itf of a compensation type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'compensation' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a pension type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'pension' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a burial type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'burial' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'fails if passed with wrong type' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", params: { type: 'test' }, headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end

    it 'fails if none is passed in for poa request' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", headers: headers.merge(auth_header)
        expect(response.status).to eq(400)
      end
    end

    it 'fails if none is passed in for non-poa request' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", headers: auth_header, params: ''
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#validate' do
    before do
      stub_mpi
    end

    it 'returns a response when valid' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: data.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('intentToFileValidation')
      end
    end

    it 'returns a response when invalid' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(response.status).to eq(422)
        expect(parsed['errors']).not_to be_empty
      end
    end

    it 'responds properly when JSON parse error' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: 'hello', headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end
  end
end
