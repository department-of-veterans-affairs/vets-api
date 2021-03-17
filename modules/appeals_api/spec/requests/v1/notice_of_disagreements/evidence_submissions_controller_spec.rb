# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers

  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  describe '#show' do
    it 'successfully requests the evidence submissions' do
      get "#{path}#{notice_of_disagreement.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'queries all evidence submissions for the nod' do
      submissions = AppealsApi::EvidenceSubmissionSerializer.new(evidence_submissions).serializable_hash

      get "#{path}#{notice_of_disagreement.id}"

      body = JSON.parse(response.body)['data']
      serialized = JSON.parse(submissions[:data].to_json)

      expect(body).to match_array(serialized)
    end
  end

  describe '#create' do
    let(:uploaded_file) { Rack::Test::UploadedFile }

    it 'successfully responds to a valid document upload' do
      valid_doc = fixture_filepath('expected_10182_minimum.pdf')
      valid_params = { document: uploaded_file.new(valid_doc), uuid: '1234' }
      post(path, params: valid_params)
      expect(response).to have_http_status(:ok)
    end

    it 'responds with an error document upload is invalid' do
      oversize_doc = fixture_filepath('oversize_11x17.pdf')
      invalid_params = { document: uploaded_file.new(oversize_doc), uuid: '6789' }
      post(path, params: invalid_params)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
