# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::SupplementalClaims::V0::EvidenceSubmissions', type: :request do
  include FixtureHelpers

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#show' do
    let(:supplemental_claim) { create(:supplemental_claim_v0) }
    let(:evidence_submissions) { create_list(:evidence_submission_v0, 3, supportable: supplemental_claim) }
    let(:data) { JSON.parse(response.body)&.dig('data') }
    let(:guid) { evidence_submissions.sample.guid }
    let(:path) { "/services/appeals/supplemental-claims/v0/evidence-submissions/#{guid}" }
    let(:scopes) { %w[system/SupplementalClaims.read] }

    describe 'responses' do
      before do
        stub_upload_location
        with_openid_auth(scopes) { |auth_header| get(path, headers: auth_header) }
      end

      it 'successfully returns details for the evidence submission' do
        expect(response).to have_http_status(:ok)
        expect(data['id']).to eq guid
        expect(data['type']).to eq('evidenceSubmission')
        expect(data['attributes']['status']).to eq('pending')
        expect(data['attributes']['appealId']).to eq(supplemental_claim.id)
        expect(data['attributes']['appealType']).to eq('SupplementalClaim')
      end

      context "when using a Veteran token whose ICN does not match the associated NOD's veteran_icn" do
        let(:scopes) { %w[veteran/SupplementalClaims.read] }
        let(:supplemental_claim) { create(:supplemental_claim_v0, veteran_icn: '1111111111V111111') }

        it 'returns a 403' do
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the record is not found' do
        let(:guid) { '00000000-0000-0000-0000-000000000000' }

        it 'returns a 404' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'with status simulation' do
      before do
        with_settings(Settings, vsp_environment: 'development') do
          with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
            stub_upload_location
            with_openid_auth(scopes) do |auth_header|
              get(path, headers: auth_header.merge({ 'Status-Simulation' => 'error' }))
            end
          end
        end
      end

      it 'simulates the given status' do
        expect(data.dig('attributes', 'status')).to eq('error')
      end
    end

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: AppealsApi::SupplementalClaims::V0::SupplementalClaims::EvidenceSubmissionsController::OAUTH_SCOPES[:GET]
    ) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let!(:supplemental_claim) { create(:supplemental_claim_v0) }
    let(:sc_id) { supplemental_claim.id }
    let(:ssn) { '123456789' }
    let(:data) { { ssn:, scId: sc_id } }
    let(:params) { data.to_json }
    let(:consumer_username) { 'test' }
    let(:headers) { { 'X-Consumer-Username' => consumer_username, 'Content-Type' => 'application/json' } }
    let(:path) { '/services/appeals/supplemental-claims/v0/evidence-submissions' }
    let(:json_body) { JSON.parse(response.body) }
    let(:scopes) { %w[system/SupplementalClaims.write] }

    describe 'successes' do
      before do
        stub_upload_location
        with_openid_auth(scopes) do |auth_header|
          post(path, params:, headers: headers.merge(auth_header))
        end
      end

      it 'succeeds and stores the source on the submission record' do
        expect(response).to have_http_status(:created)

        updated_record = AppealsApi::EvidenceSubmission.find_by(guid: json_body['data']['id'])
        expect(updated_record.source).to eq consumer_username
      end

      context 'when PII has already been expunged from the supplemental claim record' do
        let(:supplemental_claim) do
          sc = create(:supplemental_claim_v0)
          sc.update!(auth_headers: nil, form_data: nil)
          sc
        end

        it 'succeeds anyway' do
          expect(response).to have_http_status(:created)
        end
      end
    end

    describe 'errors' do
      before do
        with_openid_auth(scopes) do |auth_header|
          post(path, params:, headers: headers.merge(auth_header))
        end
      end

      context 'when body is not JSON' do
        let(:params) { 'this-is-not-json' }

        it 'returns a 400 error' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context "when using a veteran token whose ICN does not match the corresponding supplemental claim's icn" do
        let(:notice_of_disagreement) do
          create(:notice_of_disagreement_v0, :board_review_evidence_submission, veteran_icn: '1111111111V111111')
        end

        let(:scopes) { %w[veteran/NoticeOfDisagreements.write] }

        it 'returns a 403 error' do
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the corresponding supplemental claim record is not found' do
        let(:data) { { scId: '00000000-0000-0000-0000-000000000000', ssn: } }

        it 'returns a 404 error' do
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when SSN and the SC UUID are provided' do
        context 'when the SSN provided does not match the SSN on the appeal record' do
          let(:data) { { scId: sc_id, ssn: '000000000' } }

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when a location cannot be generated' do
          let(:data) { { scId: sc_id, ssn: } }

          before do
            allow_any_instance_of(VBADocuments::UploadSubmission).to(
              receive(:get_location).and_raise('Unable to provide document upload location')
            )
          end

          it 'returns a 500 error' do
            expect(response).to have_http_status(:error)
          end
        end
      end

      context 'when SSN is missing' do
        let(:data) { { scId: sc_id } }

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when SC UUID is missing' do
        let(:data) { { ssn: } }

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'auth behavior' do
      controller_klass = AppealsApi::SupplementalClaims::V0::SupplementalClaims::EvidenceSubmissionsController
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: controller_klass::OAUTH_SCOPES[:POST],
        success_status: :created
      ) do
        def make_request(auth_header)
          stub_upload_location
          post(path, params:, headers: headers.merge(auth_header))
        end
      end
    end
  end
end
