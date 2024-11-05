# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::Forms::10182', type: :request do
  def base_path(path)
    "/services/appeals/notice-of-disagreements/v0/#{path}"
  end

  let(:default_headers) { fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json' }
  let(:default_data) { fixture_as_json 'notice_of_disagreements/v0/valid_10182.json' }
  let(:min_data) { fixture_as_json 'notice_of_disagreements/v0/valid_10182_minimum.json' }
  let(:max_data) { fixture_as_json 'notice_of_disagreements/v0/valid_10182_extra.json' }
  let(:parsed_response) { JSON.parse(response.body) }
  let(:other_icn) { '1111111111V111111' }

  describe '#schema' do
    let(:path) { base_path 'schemas/10182' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(
        AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
      ) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response).to have_http_status(:ok)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 10182')
      expect(response.body).to include('{"$ref":"address.json"}')
      expect(response.body).to include('{"$ref":"phone.json"}')
    end

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
    ) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'forms/10182' }
    let(:data) { default_data }
    let(:params) { data.to_json }
    let(:headers) { default_headers }

    describe 'auth behavior' do
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST],
        success_status: :created
      ) do
        def make_request(auth_header)
          post(path, params:, headers: headers.merge(auth_header))
        end
      end
    end

    describe 'responses' do
      let(:created_notice_of_disagreement) { AppealsApi::NoticeOfDisagreement.find(parsed_response.dig('data', 'id')) }
      let(:scopes) { %w[system/NoticeOfDisagreements.write] }

      before do
        with_openid_auth(scopes) do |auth_header|
          post(path, params:, headers: headers.merge(auth_header))
        end
      end

      it 'returns 201 status' do
        expect(response).to have_http_status(:created)
      end

      it 'creates an NOD record having api_version: "V0"' do
        expect(created_notice_of_disagreement.api_version).to eq('V0')
      end

      it 'includes the form_data with PII in the serialized response' do
        expect(parsed_response.dig('data', 'attributes', 'formData')).to be_present
      end

      context 'when body does not match schema' do
        let(:data) do
          default_data['data']['attributes']['veteran'].delete('icn')
          default_data['data']['attributes']['veteran'].delete('firstName')
          default_data
        end

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
          expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn', 'firstName')
        end
      end

      context 'when veteran birth date is not in the past' do
        let(:data) do
          default_data['data']['attributes']['veteran']['birthDate'] = DateTime.tomorrow.strftime('%F')
          default_data
        end

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('Date must be in the past')
          expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/veteran/birthDate')
        end
      end

      context 'when claimant birth date is not in the past' do
        let(:data) do
          max_data['data']['attributes']['claimant']['birthDate'] = DateTime.tomorrow.strftime('%F')
          max_data
        end

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('Date must be in the past')
          expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/claimant/birthDate')
        end
      end

      context 'when body is not JSON' do
        let(:params) { 'this-is-not-json' }

        it 'returns a 400 error' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      describe 'metadata' do
        let(:saved_appeal) { AppealsApi::NoticeOfDisagreement.find(parsed_response['data']['id']) }

        context 'central_mail_business_line' do
          it 'is populated with the correct value' do
            expect(saved_appeal.metadata).to include({ 'central_mail_business_line' => 'BVA' })
          end
        end

        context 'potential_write_in_issue_count' do
          context 'with no write-in issues' do
            it 'is populated with the correct value' do
              expect(saved_appeal.metadata).to include({ 'potential_write_in_issue_count' => 0 })
            end
          end

          context 'with write-in issues' do
            let(:data) do
              d = default_data
              d['included'].push(
                {
                  'type' => 'appealableIssue',
                  'attributes' => { 'issue' => 'write-in issue text', 'decisionDate' => '1999-09-09' }
                }
              )
              d
            end

            it 'is populated with the correct value' do
              expect(saved_appeal.metadata).to include({ 'potential_write_in_issue_count' => 1 })
            end
          end
        end
      end

      context "with a veteran token where the token's ICN doesn't match the submitted ICN" do
        let(:scopes) { %w[veteran/NoticeOfDisagreements.write] }
        let(:data) do
          default_data['data']['attributes']['veteran']['icn'] = other_icn
          default_data
        end

        it 'returns a 403 Forbidden error' do
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe '#show' do
    let(:id) { create(:notice_of_disagreement_v0).id }
    let(:path) { base_path "forms/10182/#{id}" }

    describe 'auth behavior' do
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:GET]
      ) do
        def make_request(auth_header) = get(path, headers: auth_header)
      end
    end

    describe 'responses' do
      let(:scopes) { %w[veteran/NoticeOfDisagreements.read] }

      before do
        with_openid_auth(scopes) { |auth_header| get(path, headers: auth_header) }
      end

      it 'returns only minimal data with no PII' do
        expect(parsed_response.dig('data', 'attributes').keys).to eq(%w[status createDate updateDate])
      end

      context "with a veteran token where the token's ICN doesn't match the appeal's recorded ICN" do
        let(:id) { create(:notice_of_disagreement_v0, veteran_icn: other_icn).id }

        it 'returns a 403 Forbidden error' do
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'forms/10182/validate' }
    let(:params) { default_data }
    let(:headers) { default_headers }

    describe 'auth behavior' do
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
      ) do
        def make_request(auth_header) = post(path, params: params.to_json, headers: headers.merge(auth_header))
      end
    end

    describe 'responses' do
      before do
        with_openid_auth(
          AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES[:POST]
        ) do |auth_header|
          post(path, params: params.to_json, headers: headers.merge(auth_header))
        end
      end

      context 'when body matches schema' do
        it 'succeeds' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when body does not match schema' do
        let(:params) do
          default_data['data']['attributes']['veteran'].delete('icn')
          default_data['data']['attributes']['veteran'].delete('firstName')
          default_data
        end

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
          expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn', 'firstName')
        end
      end
    end
  end

  describe '#download' do
    let(:nod) { create(:notice_of_disagreement_v0, status: 'submitted', api_version: 'V0', pdf_version: 'v3') }
    let(:generated_path) { base_path "forms/10182/#{nod.id}/download" }

    # Delete pdfs generated by this describe group
    after(:all) do
      Dir.glob('10182-*.pdf').each { |f| FileUtils.rm_f(f) }
    end

    it_behaves_like(
      'watermarked pdf download endpoint',
      { expunged_attrs: { board_review_option: 'hearing' }, factory: :notice_of_disagreement_v0 },
      described_class: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController
    )

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: %w[veteran/NoticeOfDisagreements.read]) do
        def make_request(auth_header)
          get(generated_path, headers: auth_header)
        end
      end
    end

    describe 'icn parameter' do
      it_behaves_like 'GET endpoint with optional Veteran ICN parameter', {
        scope_base: 'NoticeOfDisagreements',
        skip_ssn_lookup_tests: true
      }
    end
  end
end
