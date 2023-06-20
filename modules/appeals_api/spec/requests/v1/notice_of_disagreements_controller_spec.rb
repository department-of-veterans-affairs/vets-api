# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreementsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v1/decision_reviews/#{path}"
  end

  let(:data) { fixture_to_s 'decision_reviews/v1/valid_10182.json' }
  let(:minimum_valid_data) { fixture_to_s 'decision_reviews/v1/valid_10182_minimum.json' }
  let(:invalid_data) { fixture_to_s 'decision_reviews/v1/invalid_10182.json' }
  let(:headers) { fixture_as_json 'decision_reviews/v1/valid_10182_headers.json' }
  let(:minimum_required_headers) { fixture_as_json 'decision_reviews/v1/valid_10182_headers_minimum.json' }
  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'notice_of_disagreements' }

    context 'when all headers are present and valid' do
      it 'creates an NOD and persists the data' do
        post(path, params: data, headers:)
        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])

        expect(nod.source).to eq('va.gov')
        expect(nod.veteran_icn).to eq('1013062086V794840')
        expect(parsed['data']['type']).to eq('noticeOfDisagreement')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'with minimum valid headers' do
      it 'creates an NOD and persists the data' do
        post(path, params: minimum_valid_data, headers: minimum_required_headers)
        expect(parsed['data']['type']).to eq('noticeOfDisagreement')
      end
    end

    context 'when a required headers is missing' do
      it 'returns an error' do
        post(path, params: data, headers: minimum_required_headers.except('X-VA-SSN'))
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
      end
    end

    it 'errors when included issue text is too long' do
      mod_data = fixture_as_json('decision_reviews/v1/valid_10182.json')
      mod_data['included'][0]['attributes']['issue'] = Faker::Lorem.characters(number: 500)
      post(path, params: JSON.dump(mod_data), headers: minimum_required_headers)
      expect(response.status).to eq 422
      expect(parsed['errors'][0]['title']).to eq 'Invalid length'
      expect(parsed['errors'][0]['source']['pointer']).to eq '/included/0/attributes/issue'
    end

    it 'create the job to build the PDF' do
      client_stub = instance_double('CentralMail::Service')
      faraday_response = instance_double('Faraday::Response')

      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)

      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    notice_of_disagreement_received: 'veteran_template',
                    notice_of_disagreement_received_claimant: 'claimant_template') do
        client = instance_double(VaNotify::Service)
        allow(VaNotify::Service).to receive(:new).and_return(client)
        allow(client).to receive(:send_email)

        Sidekiq::Testing.inline! do
          post(path, params: data, headers:)
        end

        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])
        expect(nod.status).to eq('submitted')
      end
    end

    context 'keeps track of board_review_option' do
      let(:path) { base_path('notice_of_disagreements') }

      it 'evidence_submission' do
        post(path, params: minimum_valid_data, headers: minimum_required_headers)
        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])

        expect(nod.board_review_option).to eq('evidence_submission')
      end

      it 'hearing' do
        post(path, params: data, headers:)
        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])

        expect(nod.board_review_option).to eq('hearing')
      end
    end

    context 'returns 422 when birth date is not a date' do
      let(:error_content) do
        { 'status' => 422, 'detail' => "'apricot' did not match the defined pattern" }
      end

      it 'when given a string for the birth date ' do
        headers.merge!('X-VA-Birth-Date' => 'apricot')
        post(path, params: data.to_json, headers:)
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
      end
    end

    context 'returns 422 when decison date is not a date' do
      let(:error_content) do
        { 'status' => 422, 'detail' => "'banana' did not fit within the defined length limits" }
      end

      it 'when given a string for the contestable issues decision date ' do
        params = JSON.parse(data)
        params['included'][0]['attributes'].merge!('decisionDate' => 'banana')
        post(path, params: params.to_json, headers:)
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['title']).to include('Invalid format')
        expect(parsed['errors'][0]['detail']).to include("'banana' did not match the defined format")
      end
    end

    context 'keeps track of which version of the api it is serving' do
      it 'V1' do
        path = base_path('notice_of_disagreements')

        post(path, params: minimum_valid_data, headers: minimum_required_headers)
        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])

        expect(nod.api_version).to eq('V1')
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'notice_of_disagreements/validate' }

    context 'when validation passes' do
      it 'returns a valid response' do
        post(path, params: data, headers:)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('noticeOfDisagreementValidation')
      end
    end

    context 'when validation fails due to invalid data' do
      before { post(path, params: invalid_data, headers:) }

      it 'returns an error response' do
        expect(response.status).to eq(422)
        expect(parsed['errors']).not_to be_empty
      end

      it 'returns error objects in JSON API 1.1 ErrorObject format' do
        expected_keys = %w[code detail meta source status title]
        expect(parsed['errors'].first.keys).to include(*expected_keys)
        expect(parsed['errors'][0]['meta']['missing_fields']).to eq ['address']
        expect(parsed['errors'][0]['source']['pointer']).to eq '/data/attributes/veteran'
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
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end
  end

  describe '#schema' do
    let(:path) { base_path 'notice_of_disagreements/schema' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)
    end
  end

  describe '#show' do
    let(:path) { base_path 'notice_of_disagreements/' }

    it 'returns a notice_of_disagreement with all of its data' do
      uuid = create(:notice_of_disagreement).id
      get("#{path}#{uuid}")
      expect(response.status).to eq(200)
      expect(parsed['data']['attributes'].key?('form_data')).to be false
    end

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          uuid = create(:notice_of_disagreement).id
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

  # rubocop:disable Layout/LineLength
  describe '#render_model_errors' do
    let(:path) { base_path 'notice_of_disagreements' }
    let(:data) { JSON.parse(minimum_valid_data) }

    it 'returns model errors in JSON API 1.1 ErrorObject format' do
      data['data']['attributes']['boardReviewOption'] = 'hearing'

      post(path, params: data.to_json, headers:)

      expect(response.status).to eq(422)
      expect(parsed['errors'][0]['source']['pointer']).to eq('/data/attributes/hearingTypePreference')
      expect(parsed['errors'][0]['detail']).to eq("If '/data/attributes/boardReviewOption' 'hearing' is selected, '/data/attributes/hearingTypePreference' must also be present")
    end
  end
  # rubocop:enable Layout/LineLength
end
