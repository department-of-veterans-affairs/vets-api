# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement, :board_review_hearing) }
  let(:headers) { fixture_as_json 'valid_10182_headers.json', version: 'v1' }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  let(:parsed) { JSON.parse(response.body) }

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#create' do
    context 'when corresponding notice of disagreement record not found' do
      it 'returns an error' do
        stub_upload_location
        post(path, params: { nod_uuid: 1979 }, headers:)

        expect(response.status).to eq 404
        expect(response.body).to include 'not found'
      end
    end

    context 'when corresponding notice of disagreement record found' do
      it "returns an error if nod 'boardReviewOption' is not 'evidence_submission'" do
        stub_upload_location
        post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)

        expect(response.status).to eq 422
        expect(response.body).to include "'boardReviewOption' must be 'evidence_submission'"
      end

      context "when nod record 'auth_headers' are present" do
        it 'returns success with 202' do
          stub_upload_location
          notice_of_disagreement.update(board_review_option: 'evidence_submission')
          post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)

          expect(response.status).to eq 202
          expect(response.body).to include notice_of_disagreement.id
        end

        it "returns an error if request 'headers['X-VA-SSN'] and NOD record SSNs do not match" do
          stub_upload_location
          notice_of_disagreement.update(board_review_option: 'evidence_submission')
          headers['X-VA-SSN'] = '1111111111'
          post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)

          expect(response.status).to eq 422
          expect(response.body).to include "'X-VA-SSN' does not match"
        end
      end

      context "when nod record 'auth_headers' are not present" do
        # if PII expunged not validating for matching SSNs
        it 'creates the evidence submission and returns upload location' do
          stub_upload_location 'http://another.fakesite.com/rewrittenpath/uuid'
          notice_of_disagreement.update(board_review_option: 'evidence_submission', auth_headers: nil)
          post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)

          data = JSON.parse(response.body)['data']
          expect(data).to have_key('id')
          expect(data).to have_key('type')
          expect(data['attributes']['status']).to eq('pending')
          expect(data['attributes']['appealId']).to eq(notice_of_disagreement.id)
          expect(data['attributes']['appealType']).to eq('NoticeOfDisagreement')
          expect(data['attributes']['location']).to eq('http://another.fakesite.com/rewrittenpath/uuid')
        end
      end

      it 'returns an error if location cannot be generated' do
        allow_any_instance_of(VBADocuments::UploadSubmission).to(
          receive(:get_location).and_raise('Unable to provide document upload location')
        )
        notice_of_disagreement.update(board_review_option: 'evidence_submission', auth_headers: nil)
        post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)

        expect(response.status).to eq 500
        expect(response.body).to include('Unable to provide document upload location')
      end
    end

    it "returns an error when 'nod_uuid' parameter is missing" do
      stub_upload_location
      post(path, headers:)

      expect(response.status).to eq 400
      expect(response.body).to include 'Must supply a corresponding NOD'
    end

    it 'stores the source from headers' do
      stub_upload_location
      notice_of_disagreement.update(board_review_option: 'evidence_submission')
      post(path, params: { nod_uuid: notice_of_disagreement.id }, headers:)
      data = JSON.parse(response.body)['data']
      record = AppealsApi::EvidenceSubmission.find_by(guid: data['id'])
      expect(record.source).to eq headers['X-Consumer-Username']
    end
  end

  describe '#show' do
    it 'successfully requests the evidence submission' do
      get "#{path}#{evidence_submissions.sample.guid}"
      expect(response).to have_http_status(:ok)
    end

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          es = evidence_submissions.sample
          status_simulation_headers = { 'Status-Simulation' => 'error' }
          get "#{path}#{es.guid}", headers: status_simulation_headers
          submission = JSON.parse(response.body)
          expect(submission.dig('data', 'attributes', 'status')).to eq('error')
        end
      end
    end

    it 'returns details for the evidence submission' do
      es = evidence_submissions.sample
      nod_uuid = es.supportable_id
      get "#{path}#{es.guid}"
      submission = JSON.parse(response.body)['data']

      expect(submission['id']).to eq es.guid
      expect(submission['type']).to eq('evidenceSubmission')
      expect(submission['attributes']['status']).to eq('pending')
      expect(submission['attributes']['appealId']).to eq(nod_uuid)
      expect(submission['attributes']['appealType']).to eq('NoticeOfDisagreement')
    end

    it 'returns an error if record is not found' do
      get "#{path}/bueller"
      expect(response.status).to eq 404
      expect(response.body).to include 'Record not found'
    end
  end
end
