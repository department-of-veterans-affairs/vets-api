# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::EvidenceSubmissions', type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement_v0, :board_review_evidence_submission) }

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#show' do
    let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
    let(:response_data) { JSON.parse(response.body)&.dig('data') }
    let(:guid) { evidence_submissions.sample.guid }
    let(:path) { "/services/appeals/notice-of-disagreements/v0/evidence-submissions/#{guid}" }
    let(:scopes) { %w[system/NoticeOfDisagreements.read] }

    describe 'responses' do
      before do
        stub_upload_location
        with_openid_auth(scopes) { |auth_header| get(path, headers: auth_header) }
      end

      context 'success' do
        it 'returns details for the evidence submission' do
          expect(response).to have_http_status(:ok)
          expect(response_data['id']).to eq(guid)
          expect(response_data['type']).to eq('evidenceSubmission')
          expect(response_data['attributes']['status']).to eq('pending')
          expect(response_data['attributes']['appealId']).to eq(notice_of_disagreement.id)
          expect(response_data['attributes']['appealType']).to eq('NoticeOfDisagreement')
        end
      end

      context "when using a Veteran token whose ICN does not match the associated NOD's veteran_icn" do
        let(:scopes) { %w[veteran/NoticeOfDisagreements.read] }
        let(:notice_of_disagreement) do
          create(:notice_of_disagreement_v0, :board_review_evidence_submission, veteran_icn: '1111111111V111111')
        end

        it 'returns a 403' do
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the submission record is not found' do
        let(:guid) { SecureRandom.uuid }

        it 'returns a 404' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe 'auth behavior' do
      controller_klass = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::EvidenceSubmissionsController
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: controller_klass::OAUTH_SCOPES[:GET]
      ) do
        def make_request(auth_header) = get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let(:consumer_username) { 'test' }
    let(:file_number) { notice_of_disagreement.veteran.file_number }
    let(:nod_id) { notice_of_disagreement.id }
    let(:params) { data.to_json }
    let(:data) { { fileNumber: file_number, nodId: nod_id } }
    let(:headers) { { 'X-Consumer-Username' => consumer_username, 'Content-Type' => 'application/json' } }
    let(:path) { '/services/appeals/notice-of-disagreements/v0/evidence-submissions' }
    let(:response_data) { JSON.parse(response.body)&.dig('data') }
    let(:scopes) { %w[system/NoticeOfDisagreements.write] }

    before do
      stub_upload_location
      with_openid_auth(scopes) do |auth_header|
        post(path, params:, headers: headers.merge(auth_header))
      end
    end

    describe 'responses' do
      describe 'successes' do
        context 'when provided fileNumber matches the NOD' do
          it 'succeeds and store the source on the submission record' do
            expect(response).to have_http_status(:created)

            updated_record = AppealsApi::EvidenceSubmission.find_by(guid: response_data['id'])
            expect(updated_record.source).to eq consumer_username
          end
        end

        context 'when PII has already been expunged from the NOD record' do
          let(:notice_of_disagreement) do
            nod = create(:notice_of_disagreement_v0, :board_review_evidence_submission)
            nod.update!(auth_headers: nil, form_data: nil)
            nod
          end

          it 'succeeds anyway' do
            expect(response).to have_http_status(:created)
          end
        end
      end

      describe 'errors' do
        context 'when body is not JSON' do
          let(:params) { 'this-is-not-json' }

          it 'returns a 400 error' do
            expect(response).to have_http_status(:bad_request)
          end
        end

        context "when using a veteran token whose ICN does not match the corresponding notice of disagreement's icn" do
          let(:notice_of_disagreement) do
            create(:notice_of_disagreement_v0, :board_review_evidence_submission, veteran_icn: '1111111111V111111')
          end

          let(:scopes) { %w[veteran/NoticeOfDisagreements.write] }

          it 'returns a 403 error' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'when the corresponding notice of disagreement is not found' do
          let(:nod_id) { '111111111111-1111-1111-1111-11111111' }

          it 'returns a 404 error' do
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'when the File Number provided does not match the File Number on the NOD record' do
          let(:file_number) { '000000000' }

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when File Number is missing' do
          let(:file_number) {}

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when NOD UUID is missing' do
          let(:nod_id) {}

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    controller_klass = AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::EvidenceSubmissionsController
    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: controller_klass::OAUTH_SCOPES[:POST],
      success_status: :created
    ) do
      def make_request(auth_header)
        post(path, params:, headers: headers.merge(auth_header))
      end
    end
  end
end
