# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796043735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-VA-EDIPI': '1007697216',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-User': 'adhoc.test.user',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-LOA' => '3',
      'X-VA-Gender': 'M' }
  end

  describe '#526' do
    let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json')) }
    let(:path) { '/services/claims/v0/forms/526' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '526.json')) }

    it 'returns a successful get response with json schema' do
      get path, headers: headers
      json_schema = JSON.parse(response.body)['data'][0]
      expect(json_schema).to eq(JSON.parse(schema))
    end

    it 'should return a successful response with all the data' do
      klass = EVSS::DisabilityCompensationForm::ServiceAllClaim
      allow_any_instance_of(klass).to receive(:validate_form526).and_return(true)
      post path, params: data, headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed['data']['type']).to eq('claims_api_claim')
      expect(parsed['data']['attributes']['status']).to eq('pending')
    end

    it 'should return a unsuccessful response without mvi' do
      allow_any_instance_of(ClaimsApi::Veteran).to receive(:mvi_record?).and_return(false)
      post path, params: data, headers: headers
      expect(response.status).to eq(404)
    end

    it 'should create the sidekick job' do
      klass = EVSS::DisabilityCompensationForm::ServiceAllClaim
      expect_any_instance_of(klass).to receive(:validate_form526).and_return(true)
      expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
      post path, params: data, headers: headers
    end

    it 'should set the source' do
      klass = EVSS::DisabilityCompensationForm::ServiceAllClaim
      expect_any_instance_of(klass).to receive(:validate_form526).and_return(true)
      post path, params: data, headers: headers
      token = JSON.parse(response.body)['data']['attributes']['token']
      aec = ClaimsApi::AutoEstablishedClaim.find(token)
      expect(aec.source).to eq('TestConsumer')
    end

    it 'should build the auth headers' do
      auth_header_stub = instance_double('EVSS::DisabilityCompensationAuthHeaders')
      expect(EVSS::DisabilityCompensationAuthHeaders).to(receive(:new).twice { auth_header_stub })
      expect(auth_header_stub).to receive(:add_headers).twice
      post path, params: data, headers: headers
    end

    context 'with the same request already ran' do
      let!(:count) do
        post path, params: data, headers: headers
        ClaimsApi::AutoEstablishedClaim.count
      end

      it 'rejects the duplicated request' do
        post path, params: data, headers: headers
        expect(count).to eq(ClaimsApi::AutoEstablishedClaim.count)
      end
    end

    context 'validation' do
      let(:json_data) { JSON.parse data }

      it 'requires currentMailingAddress subfields' do
        params = json_data
        params['data']['attributes']['veteran']['currentMailingAddress'] = {}
        post path, params: params.to_json, headers: headers
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'].size).to eq(6)
      end

      it 'requires disability subfields' do
        params = json_data
        params['data']['attributes']['disabilities'] = [{}]
        post path, params: params.to_json, headers: headers
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'].size).to eq(2)
      end
    end

    context 'form 526 validation' do
      it 'returns a successful response when valid' do
        VCR.use_cassette('evss/disability_compensation_form/form_526_valid_validation') do
          post '/services/claims/v0/forms/526/validate', params: data, headers: headers
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_auto_established_claim_validation')
          expect(parsed['data']['attributes']['status']).to eq('valid')
        end
      end

      it 'returns a list of errors when invalid hitting EVSS' do
        VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
          post '/services/claims/v0/forms/526/validate', params: data, headers: headers
          parsed = JSON.parse(response.body)
          expect(response.status).to eq(422)
          expect(parsed['errors'].size).to eq(2)
        end
      end

      it 'increment counters for statsd' do
        VCR.use_cassette('evss/disability_compensation_form/form_526_invalid_validation') do
          expect(StatsD).to receive(:increment).at_least(:once)
          post '/services/claims/v0/forms/526/validate', params: data, headers: headers
        end
      end

      it 'returns a list of errors when invalid via internal validation' do
        json_data = JSON.parse data
        params = json_data
        params['data']['attributes']['veteran']['currentMailingAddress'] = {}
        post '/services/claims/v0/forms/526/validate', params: params.to_json, headers: headers
        parsed = JSON.parse(response.body)
        expect(response.status).to eq(422)
        expect(parsed['errors'].size).to eq(6)
      end
    end
  end

  describe '#upload_supporting_documents' do
    let(:auto_claim) { create(:auto_established_claim) }
    let(:params) do
      { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
    end

    it 'increases the supporting document count' do
      allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
      count = auto_claim.supporting_documents.count
      post "/services/claims/v0/forms/526/#{auto_claim.id}/attachments", params: params, headers: headers
      auto_claim.reload
      expect(auto_claim.supporting_documents.count).to eq(count + 1)
    end
  end
end
