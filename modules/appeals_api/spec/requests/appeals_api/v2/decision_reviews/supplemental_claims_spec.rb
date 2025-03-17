# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::V2::DecisionReviews::SupplementalClaims', type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v2/decision_reviews/#{path}"
  end

  let(:minimum_data) { fixture_to_s 'decision_reviews/v2/valid_200995.json' }
  let(:data) { fixture_to_s 'decision_reviews/v2/valid_200995.json' }
  let(:extra_data) { fixture_to_s 'decision_reviews/v2/valid_200995_extra.json' }
  let(:headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers.json' }
  let(:max_headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers_extra.json' }

  let(:parsed) { JSON.parse(response.body) }

  describe '#index' do
    let(:path) { base_path 'supplemental_claims' }

    context 'with minimum required headers' do
      it 'returns all SCs for the given Veteran' do
        uuid1 = create(:supplemental_claim, veteran_icn: '1013062086V794840').id
        uuid2 = create(:supplemental_claim, veteran_icn: '1013062086V794840').id
        create(:supplemental_claim, veteran_icn: 'something_else')

        get(path, headers: max_headers)

        expect(parsed['data'].length).to eq(2)
        # Returns SCs in desc creation date, so expect 2 before 1
        expect(parsed['data'][0]['id']).to eq(uuid2)
        expect(parsed['data'][1]['id']).to eq(uuid1)
        # Strips out form_data
        expect(parsed['data'][1]['attributes'].key?('form_data')).to be false
      end
    end

    context 'when no SCs for the requesting Veteran exist' do
      it 'returns an empty array' do
        create(:supplemental_claim, veteran_icn: 'someone_else')
        create(:supplemental_claim, veteran_icn: 'also_someone_else')

        get(path, headers: max_headers)

        expect(parsed['data'].length).to eq(0)
      end
    end

    context 'when no ICN is provided' do
      it 'returns a 422 error' do
        get(path, headers: max_headers.except('X-VA-ICN'))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['detail']).to include('X-VA-ICN is required')
      end
    end

    context 'when provided ICN is in an invalid format' do
      it 'returns a 422 error' do
        get(path, headers: { 'X-VA-ICN' => '1393231' })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['detail']).to include('X-VA-ICN has an invalid format')
      end
    end

    it_behaves_like 'an endpoint requiring gateway origin headers', headers: { 'X-VA-ICN' => '1013062086V794840' } do
      def make_request(headers)
        get(path, headers:)
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'supplemental_claims' }

    context 'with minimum required headers' do
      it 'creates an SC and persists the data' do
        post(path, params: data, headers:)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.source).to eq('va.gov')
        expect(sc.api_version).to eq('V2')
        expect(sc.veteran_icn).to eq('1013062086V794840')
        expect(parsed['data']['type']).to eq('supplementalClaim')
        expect(parsed['data']['attributes']['status']).to eq('pending')
        expect(parsed.dig('data', 'attributes', 'formData')).to be_a Hash
      end

      it 'stores the evidenceType(s) in metadata' do
        post(path, params: data, headers:)
        sc = AppealsApi::SupplementalClaim.find(parsed['data']['id'])
        data_evidence_type = JSON.parse(data).dig(*%w[data attributes evidenceSubmission evidenceType])

        expect(sc.metadata.dig('form_data', 'evidence_type')).to eq(data_evidence_type)
      end
    end

    context 'when icn header is present' do
      let(:icn_updater_sidekiq_worker) { class_double(AppealsApi::AddIcnUpdater) }

      before do
        allow(AppealsApi::AddIcnUpdater).to receive(:new).and_return(icn_updater_sidekiq_worker)
        allow(icn_updater_sidekiq_worker).to receive(:perform_async)
      end

      it 'adds header ICN' do
        post(path, params: extra_data, headers: max_headers)
        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.source).to eq('va.gov')
        expect(sc.veteran_icn).to eq('1013062086V794840')
        # since icn is already provided in header, the icn updater sidekiq worker is redundant and skipped
        expect(icn_updater_sidekiq_worker).not_to have_received(:perform_async)
      end
    end

    context 'when icn header is present but does not meet length requirements' do
      let(:icn) { '1393231' }

      it 'returns a 422 error with details' do
        post(path, params: extra_data, headers: headers.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid length')
        expect(error['detail']).to include("'#{icn}' did not fit within the defined length limits")
      end
    end

    context 'when icn header is present but does not meet pattern requirements' do
      let(:icn) { '49392810394830103' }

      it 'returns a 422 error with details' do
        post(path, params: extra_data, headers: headers.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid pattern')
        expect(error['detail']).to include("'#{icn}' did not match the defined pattern")
      end
    end

    context 'when ssn header is missing' do
      it 'responds with status :unprocessable_entity' do
        post(path, params: data, headers: headers.except('X-VA-SSN'))
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(response.body).to include('Missing required fields')
        expect(response.body).to include('X-VA-SSN')
      end
    end

    context 'when phone number is too long' do
      it 'responds with status :unprocessable_entity' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['veteran'].merge!(
          { 'phone' => { 'areaCode' => '999', 'phoneNumber' => '12345678901234567890',
                         'phoneNumberExt' => '1234567890' } }
        )

        post(path, params: mod_data.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid pattern')
        expect(response.body).to include('/data/attributes/veteran/phone/phoneNumber')
      end
    end

    context 'when contestable issue text is too long' do
      it 'responds with status :unprocessable_entity' do
        mod_data = JSON.parse(data)
        mod_data['included'][0]['attributes']['issue'] =
          'Powder chocolate bar shortbread jelly beans brownie. Jujubes gummies sweet tart dragée halvah fruitcake. ' \
          'Cake tart I love apple pie candy canes tiramisu. Lemon drops muffin marzipan apple pie.'

        post(path, params: mod_data.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid length')
        expect(response.body).to include('attributes/issue')
      end
    end

    context 'when invalid headers supplied' do
      it 'errors when veteran birth date is in the future' do
        invalid_headers = headers.merge!(
          { 'X-VA-Birth-Date' => '3000-12-31' }
        )

        post(path, params: data, headers: invalid_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['source']).to eq({ 'header' => 'X-VA-Birth-Date' })
        expect(parsed['errors'][0]['detail']).to eq 'Date must be in the past: 3000-12-31'
      end
    end

    context 'returns 422 when birth date is not a date' do
      it 'when given a string for the birth date' do
        headers.merge!({ 'X-VA-Birth-Date' => 'apricot' })

        post(path, params: data.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
      end
    end

    context 'returns 422 when decision date is not a date' do
      it 'errors when given a string for the contestable issues decision date' do
        sc_data = JSON.parse(data)
        sc_data['included'][0]['attributes'].merge!('decisionDate' => 'banana')

        post(path, params: sc_data.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['title']).to include('Invalid format')
        expect(parsed['errors'][0]['detail']).to include("'banana' did not match the defined format")
      end

      it 'errors when given a decision date in the future' do
        sc_data = JSON.parse(data)
        sc_data['included'][0]['attributes'].merge!('decisionDate' => '3000-01-02')

        post(path, params: sc_data.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['source']['pointer']).to eq '/data/included[0]/attributes/decisionDate'
        expect(parsed['errors'][0]['title']).to eq 'Value outside range'
        expect(parsed['errors'][0]['detail']).to eq 'Date must be in the past: 3000-01-02'
      end
    end

    context 'form5103Acknowledged' do
      context 'when benefitType = compensation' do
        it 'fails if form5103Acknowledged = false' do
          mod_data = JSON.parse(extra_data)
          mod_data['data']['attributes']['form5103Acknowledged'] = false

          post(path, params: mod_data.to_json, headers:)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed['errors']).to be_an Array
          expect(response.body).to include('/data/attributes/form5103Acknowledged')
          expect(response.body).to include('https://www.va.gov/disability/how-to-file-claim/evidence-needed')
        end

        it 'fails if form5103Acknowledged is missing' do
          mod_data = JSON.parse(extra_data)
          mod_data['data']['attributes'].delete('form5103Acknowledged')

          post(path, params: mod_data.to_json, headers:)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed['errors']).to be_an Array
          expect(response.body).to include('Missing required fields')
          expect(response.body).to include('form5103Acknowledged')
        end
      end

      context 'when benefitType is not compensation' do
        it 'does not fail when form5103Acknowledged is missing' do
          post(path, params: minimum_data, headers:)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'evidenceType' do
      it 'with upload' do
        post(path, params: data, headers:)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.evidence_submission_indicated).to be_truthy
      end

      it 'with no evidence' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['evidenceSubmission']['evidenceType'] = %w[none]
        post(path, params: mod_data.to_json, headers:)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.evidence_submission_indicated).to be_falsey
      end

      it 'evidenceType with both none and retrieval' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['evidenceSubmission']['evidenceType'] = %w[none retrieval]
        post(path, params: mod_data.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).not_to be_empty
        expect(parsed['errors'][1]['title']).to eq('Invalid array')
      end

      it 'without retrieval section' do
        mod_data = JSON.parse(data)
        mod_data['data']['attributes']['evidenceSubmission']['evidenceType'] = %w[retrieval]

        post(path, params: mod_data.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['title']).to eq('Missing required fields')
        expect(parsed['errors'][0]['meta']['missing_fields'][0]).to eq('retrieveFrom')
      end

      it 'without upload' do
        headers_with_nvc = JSON.parse(fixture_to_s('decision_reviews/v2/valid_200995_headers_extra.json'))
        mod_data = JSON.parse(fixture_to_s('decision_reviews/v2/valid_200995_extra.json'))
        # manually setting this to simulate a submission without upload indicated
        mod_data['data']['attributes']['evidenceSubmission']['evidenceType'] = ['retrieval']

        post(path, params: mod_data.to_json, headers: headers_with_nvc)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.evidence_submission_indicated).to be_falsey
      end

      it 'with both retrieval and upload evidence' do
        headers_with_nvc = JSON.parse(fixture_to_s('decision_reviews/v2/valid_200995_headers_extra.json'))
        mod_data = JSON.parse(fixture_to_s('decision_reviews/v2/valid_200995_extra.json'))
        mod_data['data']['attributes']['evidenceSubmission']['evidenceType'] = %w[retrieval upload]
        post(path, params: mod_data.to_json, headers: headers_with_nvc)

        sc_guid = JSON.parse(response.body)['data']['id']
        sc = AppealsApi::SupplementalClaim.find(sc_guid)

        expect(sc.evidence_submission_indicated).to be_truthy
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
        post(path, params: data, headers:)
        expect(response).to have_http_status :unprocessable_entity
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
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'when request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end

    it 'updates the appeal status once submitted to central mail' do
      client_stub = instance_double(CentralMail::Service)
      faraday_response = instance_double(Faraday::Response)

      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)

      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    supplemental_claim_received: 'veteran_template',
                    supplemental_claim_received_claimant: 'claimant_template') do
        client = instance_double(VaNotify::Service)
        allow(VaNotify::Service).to receive(:new).and_return(client)
        allow(client).to receive(:send_email)

        Sidekiq::Testing.inline! do
          post(path, params: data, headers:)
        end

        sc = AppealsApi::SupplementalClaim.find_by(id: parsed['data']['id'])
        expect(sc.status).to eq('submitted')
      end
    end

    it_behaves_like 'an endpoint requiring gateway origin headers',
                    headers: {
                      'X-VA-First-Name': 'Jane',
                      'X-VA-Last-Name': 'Doe',
                      'X-VA-SSN': '123456789',
                      'X-VA-Birth-Date': '1969-12-31'
                    } do
      def make_request(headers)
        post(path, params: minimum_data, headers:)
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'supplemental_claims/validate' }
    let(:extra_headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers_extra.json' }

    context 'when validation passes' do
      it 'returns a valid response' do
        post(path, params: extra_data, headers: extra_headers)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('supplementalClaimValidation')
      end
    end

    context 'when validation fails due to invalid data' do
      before do
        data = JSON.parse(extra_data)
        data['data']['attributes']['veteran'].except!('phone', 'email')
        post(path, params: data.to_json, headers: extra_headers)
      end

      it 'returns an error response' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).not_to be_empty
      end

      it 'returns error objects in JSON API 1.1 ErrorObject format' do
        expected_keys = %w[code detail meta source status title]
        expect(parsed['errors'].first.keys).to include(*expected_keys)
        expect(parsed['errors'][0]['meta']['missing_fields']).to eq %w[phone email]
        expect(parsed['errors'][0]['source']['pointer']).to eq '/data/attributes/veteran'
      end
    end

    context 'responds with a 422 when request.body isn\'t a JSON *object*' do
      before do
        fake_io_object = OpenStruct.new string: json
        allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
      end

      context 'request.body is a JSON string' do
        let(:json) { '"Toodles!"' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: data, headers:)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end

    context 'when icn header is present but does not meet length requirements' do
      let(:icn) { '1393231' }

      it 'returns a 422 error with details' do
        post(path, params: extra_data, headers: headers.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid length')
        expect(error['detail']).to include("'#{icn}' did not fit within the defined length limits")
      end
    end

    context 'when icn header is present but does not meet pattern requirements' do
      let(:icn) { '49392810394830103' }

      it 'returns a 422 error with details' do
        post(path, params: extra_data, headers: headers.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid pattern')
        expect(error['detail']).to include("'#{icn}' did not match the defined pattern")
      end
    end

    it_behaves_like 'an endpoint requiring gateway origin headers',
                    headers: {
                      'X-VA-First-Name': 'Jane',
                      'X-VA-Last-Name': 'Doe',
                      'X-VA-SSN': '123456789',
                      'X-VA-Birth-Date': '1969-12-31'
                    } do
      def make_request(headers)
        post(path, params: minimum_data, headers:)
      end
    end
  end

  describe '#schema' do
    let(:path) { base_path 'supplemental_claims/schema' }

    it 'renders the json schema' do
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#show' do
    let(:path) { base_path 'supplemental_claims/' }

    it 'returns a supplemental_claims with all of its data' do
      uuid = create(:supplemental_claim).id
      get("#{path}#{uuid}")
      expect(response).to have_http_status(:ok)
      expect(parsed['data']['attributes'].key?('form_data')).to be false
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
      expect(response).to have_http_status(:not_found)
      expect(parsed['errors']).to be_an Array
      expect(parsed['errors']).not_to be_empty
    end
  end

  describe '#download', skip: 'temporarily skipped' do
    it_behaves_like(
      'watermarked pdf download endpoint',
      { factory: :supplemental_claim, decision_reviews: true },
      described_class: AppealsApi::V2::DecisionReviews::SupplementalClaimsController
    )
  end
end
