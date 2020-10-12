# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-VA-EDIPI': '1007697216',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-User': 'adhoc.test.user',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }

  before do
    stub_poa_verification
    stub_mvi
  end

  describe '#526' do
    let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json')) }
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '526.json')) }

    it 'returns a successful get response with json schema' do
      with_okta_user(scopes) do |auth_header|
        get path, headers: headers.merge(auth_header)
        json_schema = JSON.parse(response.body)['data'][0]
        expect(json_schema).to eq(JSON.parse(schema))
      end
    end

    it 'returns a successful response with all the data' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          post path, params: data, headers: headers.merge(auth_header)
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_claim')
          expect(parsed['data']['attributes']['status']).to eq('pending')
        end
      end
    end

    it 'creates the sidekick job' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
          post path, params: data, headers: headers.merge(auth_header)
        end
      end
    end

    it 'assigns a source' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          post path, params: data, headers: headers.merge(auth_header)
          token = JSON.parse(response.body)['data']['attributes']['token']
          aec = ClaimsApi::AutoEstablishedClaim.find(token)
          expect(aec.source).to eq('abraham lincoln')
        end
      end
    end

    it 'builds the auth headers' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          auth_header_stub = instance_double('EVSS::DisabilityCompensationAuthHeaders')
          expect(EVSS::DisabilityCompensationAuthHeaders).to(receive(:new).once { auth_header_stub })
          expect(auth_header_stub).to receive(:add_headers).once
          post path, params: data, headers: headers.merge(auth_header)
        end
      end
    end

    context 'validation' do
      let(:json_data) { JSON.parse data }

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
            "pointOfContact": {
              "pointOfContactName": 'John Doe',
              "primaryPhone": {
                "areaCode": '555',
                "phoneNumber": '555-5555'
              }
            },
            "currentlyHomeless": {
              "homelessSituationType": 'NOT_A_HOMELESS_TYPE',
              "otherLivingSituation": 'other living situations'
            }
          }
          post path, params: par.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors'].size).to eq(1)
        end
      end

      it 'requires homelessness homelessnessRisk subfields' do
        with_okta_user(scopes) do |auth_header|
          par = json_data
          par['data']['attributes']['veteran']['homelessness'] = {
            "pointOfContact": {
              "pointOfContactName": 'John Doe',
              "primaryPhone": {
                "areaCode": '555',
                "phoneNumber": '555-5555'
              }
            },
            "homelessnessRisk": {
              "homelessnessRiskSituationType": 'NOT_RISK_TYPE',
              "otherLivingSituation": 'other living situations'
            }
          }
          post path, params: par.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors'].size).to eq(1)
        end
      end

      it 'requires disability subfields' do
        with_okta_user(scopes) do |auth_header|
          params = json_data
          params['data']['attributes']['disabilities'] = [{}]
          post path, params: params.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors'].size).to eq(2)
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
              with_okta_user(scopes) do |auth_header|
                params = json_data
                params['data']['attributes']['disabilities'][0]['specialIssues'] = %w[ALS HEPC]
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response.status).to eq(200)
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
          fake_io_object = OpenStruct.new string: json
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

    context 'form 526 validation' do
      let(:path) { '/services/claims/v1/forms/526/validate' }

      it 'returns a successful response when valid' do
        VCR.use_cassette('evss/disability_compensation_form/form_526_valid_validation') do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('evss/claims/claims') do
              data = File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json'))
              post path, params: data, headers: headers.merge(auth_header)
              parsed = JSON.parse(response.body)
              expect(parsed['data']['type']).to eq('claims_api_auto_established_claim_validation')
              expect(parsed['data']['attributes']['status']).to eq('valid')
            end
          end
        end
      end

      it 'returns a list of errors when invalid hitting EVSS' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
            VCR.use_cassette('evss/claims/claims') do
              post path, params: data, headers: headers.merge(auth_header)
              parsed = JSON.parse(response.body)
              expect(response.status).to eq(422)
              expect(parsed['errors'].size).to eq(2)
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
            VCR.use_cassette('evss/claims/claims') do
              post path, params: data, headers: headers.merge(auth_header)
              expect(PersonalInformationLog.count).to be_positive
              expect(PersonalInformationLog.last.error_class).to eq('validate_form_526 Breakers::OutageException')
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

  describe '#upload_documents' do
    let(:auto_claim) { create(:auto_established_claim) }
    let(:binary_params) do
      { 'attachment1': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"),
        'attachment2': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
    end
    let(:base64_params) do
      { 'attachment1': File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/base64pdf"),
        'attachment2': File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/base64pdf") }
    end

    it 'upload 526 binary form through PUT' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: binary_params, headers: headers.merge(auth_header))
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'upload 526 base64 form through PUT' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        put("/services/claims/v1/forms/526/#{auto_claim.id}",
            params: base64_params, headers: headers.merge(auth_header))
        auto_claim.reload
        expect(auto_claim.file_data).to be_truthy
      end
    end

    it 'upload binary support docs and increases the supporting document count' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: binary_params, headers: headers.merge(auth_header))
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
  end
end
