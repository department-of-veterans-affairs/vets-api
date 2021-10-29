# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V2::DecisionReviews::SupplementalClaimsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v2/decision_reviews/#{path}"
  end

  let(:data) { fixture_to_s 'valid_200995.json' }
  let(:headers) { fixture_as_json 'valid_200995_headers.json' }

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'supplemental_claims' }

    context 'with minimum required headers' do
      it 'creates an SC and persists the data' do
        post(path, params: data, headers: headers)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.source).to eq('va.gov')
        expect(parsed['data']['type']).to eq('supplementalClaim')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'when header is missing' do
      it 'responds with status :unprocessable_entity' do
        post(path, params: data, headers: headers.except('X-VA-SSN'))
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
        expect(response.body).to include('Missing required fields')
        expect(response.body).to include('X-VA-SSN')
      end
    end

    context 'when phone number is too long' do
      it 'responds with status :unprocessable_entity ' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['veteran'].merge!(
          { 'phone' => { 'areaCode' => '999', 'phoneNumber' => '12345678901234567890',
                         'phoneNumberExt' => '1234567890' } }
        )

        post(path, params: mod_data.to_json, headers: headers)
        expect(response.status).to eq(422)
        expect(response.body).to include('Invalid pattern')
        expect(response.body).to include('/data/attributes/veteran/phone/phoneNumber')
      end
    end

    context 'when invalid headers supplied' do
      it 'returns an error' do
        invalid_headers = headers.merge!(
          { 'X-VA-Birth-Date' => '3000-12-31' }
        )

        post(path, params: data, headers: invalid_headers)

        expect(response.status).to eq(422)
        expect(parsed['errors'][0]['detail']).to eq('Veteran birth date isn\'t in the past: 3000-12-31')
      end
    end

    context 'noticeAcknowledgement' do
      it 'benefitType = compensation and noticeAcknowledgement = false' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['noticeAcknowledgement'] = false

        post(path, params: mod_data.to_json, headers: headers)
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
        expect(response.body).to include('/data/attributes/noticeAcknowledgement')
        expect(response.body).to include('https://www.va.gov/disability/how-to-file-claim/evidence-needed')
      end
    end

    context 'when request.body is a Puma::NullIO' do
      it 'responds with a 422' do
        fake_puma_null_io_object = Object.new.tap do |obj|
          def obj.class
            OpenStruct.new name: 'Puma::NullIO'
          end
        end
        expect(fake_puma_null_io_object.class.name).to eq 'Puma::NullIO'
        allow_any_instance_of(ActionDispatch::Request).to(
          receive(:body).and_return(fake_puma_null_io_object)
        )
        post(path, params: data, headers: headers)
        expect(response.status).to eq 422
        expect(JSON.parse(response.body)['errors']).to be_an Array
      end
    end

    context 'when request.body isn\'t a JSON *object*' do
      before do
        fake_io_object = OpenStruct.new string: json
        allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
      end

      context 'when request.body is a JSON string' do
        let(:json) { '"Hello!"' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers: headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'when request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers: headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end

    context 'when request body includes chars outside the windows-1252 charset' do
      it 'returns an error' do
        invalid_data = JSON.parse(data)
        invalid_data['data'].merge!(
          { 'type' => '∑upplementalClaim' }
        )

        post(path, params: invalid_data.to_json, headers: headers)

        expect(response.status).to eq(422)
        expect(parsed['errors'][0]['detail']).to include 'Invalid characters'
        expect(parsed['errors'][0]['meta']).to include 'pattern'
      end
    end

    it 'creates the job to build the PDF' do
      client_stub = instance_double('CentralMail::Service')
      faraday_response = instance_double('Faraday::Response')

      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)

      Sidekiq::Testing.inline! do
        post(path, params: data, headers: headers)
      end

      sc = AppealsApi::SupplementalClaim.find_by(id: parsed['data']['id'])
      expect(sc.status).to eq('submitted')
    end
  end

  describe '#schema' do
    let(:path) { base_path 'supplemental_claims/schema' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)
    end
  end

  describe '#show' do
    let(:path) { base_path 'supplemental_claims/' }

    it 'returns a supplemental_claims with all of its data' do
      uuid = create(:supplemental_claim).id
      get("#{path}#{uuid}")
      expect(response.status).to eq(200)
      expect(parsed.dig('data', 'attributes', 'formData')).to be_a Hash
    end

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          uuid = create(:supplemental_claim).id
          status_simulation_headers = { 'Status-Simulation' => 'error' }
          get("#{path}#{uuid}", headers: status_simulation_headers)

          expect(parsed.dig('data', 'attributes', 'status')).to eq('error')
        end
      end
    end

    it 'returns an error when given a bad uuid' do
      uuid = 0
      get("#{path}#{uuid}")
      expect(response.status).to eq(404)
      expect(parsed['errors']).to be_an Array
      expect(parsed['errors']).not_to be_empty
    end
  end
end
