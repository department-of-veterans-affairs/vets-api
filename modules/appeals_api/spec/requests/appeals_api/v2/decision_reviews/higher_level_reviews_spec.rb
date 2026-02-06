# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe 'AppealsApi::V2::DecisionReviews::HigherLevelReviews', type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v2/decision_reviews/#{path}"
  end

  let(:data_default) { fixture_to_s 'decision_reviews/v2/valid_200996_minimum.json' }
  let(:data_extra) { fixture_to_s 'decision_reviews/v2/valid_200996_extra.json' }
  let(:data_invalid) { fixture_to_s 'decision_reviews/v2/invalid_200996.json' }
  let(:headers_default) { fixture_as_json 'decision_reviews/v2/valid_200996_headers.json' }
  let(:headers_extra) { fixture_as_json 'decision_reviews/v2/valid_200996_headers_extra.json' }
  let(:headers_minimum) { fixture_as_json 'decision_reviews/v2/valid_200996_headers_minimum.json' }
  let(:headers_invalid) { fixture_as_json 'decision_reviews/v2/invalid_200996_headers.json' }
  let(:parsed) { JSON.parse(response.body) }

  before { Flipper.disable(:decision_review_hlr_form_v4_enabled) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

  describe '#index' do
    let(:path) { base_path 'higher_level_reviews' }

    context 'with minimum required headers' do
      it 'returns all HLRs for the given Veteran' do
        uuid1 = create(:higher_level_review_v2, veteran_icn: '1013062086V794840', form_data: {}).id
        uuid2 = create(:higher_level_review_v2, veteran_icn: '1013062086V794840').id
        create(:higher_level_review_v2, veteran_icn: 'something_else')

        get(path, headers: { 'X-VA-ICN' => '1013062086V794840' })

        expect(parsed['data'].length).to eq(2)
        # Returns HLRs in desc creation date, so expect 2 before 1
        expect(parsed['data'][0]['id']).to eq(uuid2)
        expect(parsed['data'][1]['id']).to eq(uuid1)
        # Strips out form_data
        expect(parsed['data'][1]['attributes'].key?('form_data')).to be false
      end
    end

    context 'when no HLRs for the requesting Veteran exist' do
      it 'returns an empty array' do
        create(:higher_level_review_v2, veteran_icn: 'someone_else')
        create(:higher_level_review_v2, veteran_icn: 'also_someone_else')

        get(path, headers: { 'X-VA-ICN' => '1013062086V794840' })

        expect(parsed['data'].length).to eq(0)
      end
    end

    context 'when no ICN is provided' do
      it 'returns a 422 error' do
        get(path, headers: headers_extra.except('X-VA-ICN'))

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
    let(:path) { base_path 'higher_level_reviews' }

    context 'with all headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: data_default, headers: headers_default)
        hlr_guid = JSON.parse(response.body)['data']['id']
        hlr = AppealsApi::HigherLevelReview.find(hlr_guid)
        expect(hlr.source).to eq('va.gov')
        expect(hlr.api_version).to eq('V2')
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
        expect(parsed.dig('data', 'attributes', 'formData')).to be_a Hash
      end
    end

    context 'with minimum required headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: data_default, headers: headers_minimum)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['formData']['data']['attributes']['benefitType']).to eq('lifeInsurance')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'with optional claimant headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: data_extra, headers: headers_extra)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'when icn header is present' do
      let(:icn_updater_sidekiq_worker) { class_double(AppealsApi::AddIcnUpdater) }

      before do
        allow(AppealsApi::AddIcnUpdater).to receive(:new).and_return(icn_updater_sidekiq_worker)
        allow(icn_updater_sidekiq_worker).to receive(:perform_async)
      end

      it 'adds header ICN' do
        post(path, params: data_extra, headers: headers_extra)
        hlr_guid = JSON.parse(response.body)['data']['id']
        hlr = AppealsApi::HigherLevelReview.find(hlr_guid)

        expect(hlr.source).to eq('va.gov')
        expect(hlr.veteran_icn).to eq('1013062086V794840')
        # since icn is already provided in header, the icn updater sidekiq worker is redundant and skipped
        expect(icn_updater_sidekiq_worker).not_to have_received(:perform_async)
      end
    end

    context 'when icn header is present but does not meet length requirements' do
      let(:icn) { '1393231' }

      it 'returns a 422 error with details' do
        post(path, params: data_extra, headers: headers_minimum.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['title']).to eql('Invalid length')
        expect(parsed['errors'][0]['detail']).to include("'#{icn}' did not fit within the defined length limits")
      end
    end

    context 'when icn header is present but does not meet pattern requirements' do
      let(:icn) { '49392810394830103' }

      it 'returns a 422 error with details' do
        post(path, params: data_extra, headers: headers_minimum.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['title']).to eql('Invalid pattern')
        expect(parsed['errors'][0]['detail']).to include("'#{icn}' did not match the defined pattern")
      end
    end

    context 'when header is missing' do
      it 'responds with status :unprocessable_entity' do
        post(path, params: data_default, headers: headers_minimum.except('X-VA-SSN'))
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
      end
    end

    context 'when phone number is too long' do
      let(:error_content) do
        { 'status' => 422, 'detail' => 'Phone number will not fit on form (20 char limit): 9991234567890x1234567890' }
      end

      it 'responds with status :unprocessable_entity' do
        data = JSON.parse(data_default)
        data['data']['attributes']['veteran'].merge!(
          { 'phone' => { 'areaCode' => '999', 'phoneNumber' => '1234567890', 'phoneNumberExt' => '1234567890' } }
        )

        post(path, params: data.to_json, headers: headers_minimum)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to include(error_content)
      end

      it 'fails when homeless is false but no address is provided' do
        data = JSON.parse(data_default)
        data['data']['attributes']['veteran']['homeless'] = false
        data['data']['attributes']['veteran'].delete('address')

        post(path, params: data.to_json, headers: headers_minimum)
        expect(response).to have_http_status(:unprocessable_entity)

        error = parsed['errors'][0]
        expect(error['title']).to eq 'Missing required fields'
        expect(error['code']).to eq '145'
        expect(error['meta']['missing_fields']).to contain_exactly('address')
      end
    end

    context 'returns 422 when birth date is not a date' do
      it 'when given a string for the birth date' do
        headers = headers_minimum
        headers['X-VA-Birth-Date'] = 'apricot'

        post(path, params: data_default.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
      end
    end

    context 'returns 422 when decison date is not a date' do
      it 'when given a string for the contestable issues decision date' do
        data = JSON.parse(data_default)
        data['included'][0]['attributes'].merge!('decisionDate' => 'banana')

        post(path, params: data.to_json, headers: headers_minimum)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).to be_an Array
        expect(parsed['errors'][0]['title']).to include('Invalid format')
        expect(parsed['errors'][0]['detail']).to include(' did not match the defined format')
      end
    end

    it 'updates the appeal status once submitted to central mail' do
      client_stub = instance_double(CentralMail::Service)
      faraday_response = instance_double(Faraday::Response)

      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)

      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    higher_level_review_received: 'veteran_template',
                    higher_level_review_received_claimant: 'claimant_template') do
        client = instance_double(VaNotify::Service)
        allow(VaNotify::Service).to receive(:new).and_return(client)
        allow(client).to receive(:send_email)

        Sidekiq::Testing.inline! do
          post(path, params: data_default, headers: headers_default)
        end

        hlr = AppealsApi::HigherLevelReview.find_by(id: parsed['data']['id'])
        expect(hlr.status).to eq('submitted')
      end
    end

    context 'when invalid headers supplied' do
      it 'returns an error' do
        post(path, params: data_default, headers: headers_invalid)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['detail']).to eq 'Date must be in the past: 3000-12-31'
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
        post(path, params: data_default, headers: headers_default)
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
          post(path, params: data_default, headers: headers_default)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'when request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: data_default, headers: headers_default)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'higher_level_reviews/validate' }

    it 'returns a response when minimal data valid' do
      post(path, params: data_default, headers: headers_default)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('higherLevelReviewValidation')
    end

    it 'returns a response when extra data valid' do
      post(path, params: data_extra, headers: headers_extra)

      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('higherLevelReviewValidation')
    end

    context 'when validation fails due to invalid data' do
      before do
        post(path, params: data_invalid, headers: headers_default)
      end

      it 'returns an error response' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).not_to be_empty
      end

      it 'returns error objects in JSON API 1.1 ErrorObject format' do
        expected_keys = %w[code detail meta source status title]
        errors = parsed['errors']
        invalid_data_type_error = errors.find { |h| h['title'] == 'Invalid data type' }
        missing_required_fields_errors = errors.select { |h| h['title'] == 'Missing required fields' }
        missing_address_error = errors.find { |h| h['source']['pointer'] == '/data/attributes/claimant/address' }

        expect(errors.count).to eq(4)
        expect(invalid_data_type_error).not_to be_nil
        expect(missing_required_fields_errors.count).to eq(3)
        expect(missing_address_error).not_to be_nil
        expect(missing_address_error['meta']['missing_fields']).to eq(%w[addressLine1 countryCodeISO2 zipCode5])
        missing_required_fields_errors.each do |error|
          expect(error.keys).to include(*expected_keys)
        end
      end
    end

    context 'responds with a 422 when request.body isn\'t a JSON *object*' do
      before do
        fake_io_object = OpenStruct.new string: json
        allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
      end

      context 'request.body is a JSON string' do
        let(:json) { '"Poodles!"' }

        it 'responds with a properly formed error object' do
          post(path, params: data_default, headers: headers_default)
          body = JSON.parse(response.body)
          expect(response).to have_http_status :unprocessable_entity
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'request.body is a JSON integer' do
        let(:json) { '33' }

        it 'responds with a properly formed error object' do
          post(path, params: data_default, headers: headers_default)
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
        post(path, params: data_extra, headers: headers_minimum.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['title']).to eql('Invalid length')
        expect(parsed['errors'][0]['detail']).to include("'#{icn}' did not fit within the defined length limits")
      end
    end

    context 'when icn header is present but does not meet pattern requirements' do
      let(:icn) { '49392810394830103' }

      it 'returns a 422 error with details' do
        post(path, params: data_extra, headers: headers_minimum.merge({ 'X-VA-ICN' => icn }))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors'][0]['title']).to eql('Invalid pattern')
        expect(parsed['errors'][0]['detail']).to include("'#{icn}' did not match the defined pattern")
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
        post(path, params: data_default, headers:)
      end
    end
  end

  describe '#schema' do
    let(:path) { base_path 'higher_level_reviews/schema' }

    it 'renders the json schema' do
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#show' do
    let(:path) { base_path 'higher_level_reviews/' }

    it 'returns a higher_level_review with all of its data' do
      uuid = create(:higher_level_review_v2).id
      get("#{path}#{uuid}")
      expect(response).to have_http_status(:ok)
      expect(parsed['data']['attributes'].key?('form_data')).to be false
    end

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          uuid = create(:higher_level_review_v2).id
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
      { factory: :higher_level_review_v2, decision_reviews: true },
      described_class: AppealsApi::V2::DecisionReviews::HigherLevelReviewsController
    )
  end
end
