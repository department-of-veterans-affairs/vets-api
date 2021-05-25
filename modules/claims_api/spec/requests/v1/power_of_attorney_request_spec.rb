# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Power of Attorney ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }

  before do
    stub_poa_verification
    stub_mpi
  end

  describe '#2122' do
    let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json')) }
    let(:path) { '/services/claims/v1/forms/2122' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '2122.json')) }

    describe 'schema' do
      it 'returns a successful get response with json schema' do
        get path
        json_schema = JSON.parse(response.body)['data'][0]
        expect(json_schema).to eq(JSON.parse(schema))
      end
    end

    context 'when poa code is valid' do
      before do
        Veteran::Service::Representative.new(poa_codes: ['074']).save!
      end

      context 'when poa code is associated with current user' do
        before do
          Veteran::Service::Representative.new(poa_codes: ['074'], first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        it 'assigns a source' do
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: headers.merge(auth_header)
            token = JSON.parse(response.body)['data']['id']
            poa = ClaimsApi::PowerOfAttorney.find(token)
            expect(poa.source_data['name']).to eq('abraham lincoln')
            expect(poa.source_data['icn'].present?).to eq(true)
            expect(poa.source_data['email']).to eq('abraham.lincoln@vets.gov')
          end
        end

        it 'returns a successful response with all the data' do
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: headers.merge(auth_header)
            parsed = JSON.parse(response.body)
            expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
            expect(parsed['data']['attributes']['status']).to eq('pending')
          end
        end
      end

      context 'when poa code is not associated with current user' do
        it 'responds with invalid poa code message' do
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: headers.merge(auth_header)
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when poa code is not valid' do
      it 'responds with invalid poa code message' do
        with_okta_user(scopes) do |auth_header|
          post path, params: data, headers: headers.merge(auth_header)
          expect(response.status).to eq(400)
        end
      end
    end

    context 'validation' do
      let(:json_data) { JSON.parse data }

      it 'requires poa_code subfield' do
        with_okta_user(scopes) do |auth_header|
          params = json_data
          params['data']['attributes']['serviceOrganization']['poaCode'] = nil
          post path, params: params.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors'].size).to eq(1)
        end
      end
    end

    describe '#check status' do
      let(:power_of_attorney) { create(:power_of_attorney, auth_headers: headers) }

      it 'return the status of a PoA based on GUID' do
        with_okta_user(scopes) do |auth_header|
          get("/services/claims/v1/forms/2122/#{power_of_attorney.id}",
              params: nil, headers: headers.merge(auth_header))
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
          expect(parsed['data']['attributes']['status']).to eq('submitted')
        end
      end
    end

    describe '#upload_power_of_attorney_document' do
      let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
      let(:binary_params) do
        { attachment: Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
      end
      let(:base64_params) do
        { attachment: File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/base64pdf") }
      end

      it 'submit binary and change the document status' do
        with_okta_user(scopes) do |auth_header|
          allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
          expect(power_of_attorney.file_data).to be_nil
          put("/services/claims/v1/forms/2122/#{power_of_attorney.id}",
              params: binary_params, headers: headers.merge(auth_header))
          power_of_attorney.reload
          expect(power_of_attorney.file_data).not_to be_nil
          expect(power_of_attorney.status).to eq('submitted')
        end
      end

      it 'submit base64 and change the document status' do
        with_okta_user(scopes) do |auth_header|
          allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
          expect(power_of_attorney.file_data).to be_nil
          put("/services/claims/v1/forms/2122/#{power_of_attorney.id}",
              params: base64_params, headers: headers.merge(auth_header))
          power_of_attorney.reload
          expect(power_of_attorney.file_data).not_to be_nil
          expect(power_of_attorney.status).to eq('submitted')
        end
      end
    end

    describe '#validate' do
      it 'returns a response when valid' do
        with_okta_user(scopes) do |auth_header|
          post "#{path}/validate", params: data, headers: headers.merge(auth_header)
          parsed = JSON.parse(response.body)
          expect(parsed['data']['attributes']['status']).to eq('valid')
          expect(parsed['data']['type']).to eq('powerOfAttorneyValidation')
        end
      end

      it 'returns a response when invalid' do
        with_okta_user(scopes) do |auth_header|
          post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers.merge(auth_header)
          parsed = JSON.parse(response.body)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed['errors']).not_to be_empty
        end
      end

      it 'responds properly when JSON parse error' do
        with_okta_user(scopes) do |auth_header|
          post "#{path}/validate", params: 'hello', headers: headers.merge(auth_header)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe '#active' do
      let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

      context 'when there is no BGS active power of attorney' do
        before do
          Veteran::Service::Representative.new(poa_codes: ['074'], first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        it 'returns a 404' do
          with_okta_user(scopes) do |auth_header|
            allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
            expect(bgs_poa_verifier).to receive(:current_poa).and_return(nil)
            get('/services/claims/v1/forms/2122/active',
                params: nil, headers: headers.merge(auth_header))
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when there is a BGS active power of attorney' do
        before do
          Veteran::Service::Representative.new(poa_codes: ['074'], first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        let(:representative_info) do
          {
            name: 'Abraham Lincoln',
            phone_number: '555-555-5555'
          }
        end

        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
            expect(bgs_poa_verifier).to receive(:current_poa).and_return(Struct.new(:code).new('HelloWorld'))
            expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
            expect_any_instance_of(
              ClaimsApi::V1::Forms::PowerOfAttorneyController
            ).to receive(:build_representative_info).and_return(representative_info)
            get('/services/claims/v1/forms/2122/active',
                params: nil, headers: headers.merge(auth_header))

            parsed = JSON.parse(response.body)
            expect(response.status).to eq(200)
            expect(parsed['data']['attributes']['representative']['service_organization']['poa_code'])
              .to eq('HelloWorld')
          end
        end
      end

      context 'when a non-accredited representative and non-veteran request active power of attorney' do
        it 'returns a 403' do
          with_okta_user(scopes) do |auth_header|
            get('/services/claims/v1/forms/2122/active',
                params: nil, headers: headers.merge(auth_header))
            expect(response.status).to eq(403)
          end
        end
      end

      describe 'additional POA info' do
        before do
          Veteran::Service::Representative.new(poa_codes: ['074'], first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        context 'when representative is part of an organization' do
          let(:user_types) { ['veteran_service_officer'] }

          it "returns the organization's name and phone" do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:validate_user_is_accredited!).and_return(nil)
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa).and_return(Struct.new(:code).new('HelloWorld'))
              expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
              expect(::Veteran::Service::Representative).to receive(:where).and_return(
                [OpenStruct.new(user_types: user_types)]
              )
              expect(::Veteran::Service::Organization).to receive(:find_by).and_return(
                OpenStruct.new(name: 'Some Great Organization', phone: '555-555-5555')
              )

              get('/services/claims/v1/forms/2122/active', params: nil, headers: headers.merge(auth_header))

              parsed = JSON.parse(response.body)

              expect(response.status).to eq(200)
              expect(parsed['data']['attributes']['representative']['service_organization']['name'])
                .to eq('Some Great Organization')
              expect(parsed['data']['attributes']['representative']['service_organization']['phone_number'])
                .to eq('555-555-5555')
            end
          end
        end

        context 'when representative is not part of an organization' do
          let(:user_types) { [] }

          it "returns the representative's name and phone" do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:validate_user_is_accredited!).and_return(nil)
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa).and_return(Struct.new(:code).new('HelloWorld'))
              expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
              allow(::Veteran::Service::Representative).to receive(:where).and_return(
                [
                  OpenStruct.new(
                    first_name: 'Tommy',
                    last_name: 'Testerson',
                    phone: '555-555-5555',
                    user_types: user_types
                  )
                ]
              )

              get('/services/claims/v1/forms/2122/active', params: nil, headers: headers.merge(auth_header))

              parsed = JSON.parse(response.body)

              expect(response.status).to eq(200)
              expect(parsed['data']['attributes']['representative']['service_organization']['name'])
                .to eq('Tommy Testerson')
              expect(parsed['data']['attributes']['representative']['service_organization']['phone_number'])
                .to eq('555-555-5555')
            end
          end
        end
      end
    end
  end
end
