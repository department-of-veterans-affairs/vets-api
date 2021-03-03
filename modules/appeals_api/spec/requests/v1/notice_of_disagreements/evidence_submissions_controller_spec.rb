# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }

  def base_path(path)
    "/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/#{path}"
  end
  # let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  describe '#show' do
    let(:path) { base_path notice_of_disagreement.id}

    it 'successfully requests the evidence submissions' do
      get path

      expect(response).to have_http_status(:ok)
    end

    it 'queries all evidence submissions for the nod' do
      submissions = AppealsApi::EvidenceSubmissionSerializer.new(evidence_submissions).serializable_hash

      get path

      body = JSON.parse(response.body)['data']
      serialized = JSON.parse(submissions[:data].to_json)

      expect(body).to match_array(serialized)
    end
  end


  describe '#upload' do
    let(:path) { base_path 'upload' }
    let(:fixtures_path) { '/modules/appeals_api/spec/fixtures/' }
    let(:file) { 'expected_10182_extra.pdf' }
    let(:upload_params) do
      { document: Rack::Test::UploadedFile.new("#{::Rails.root}#{fixtures_path}#{file}"), uuid: '1234' }
    end

    it 'successfully responds to document upload' do
      post(path, params: upload_params)
      expect(response).to have_http_status(:ok)
    end
  end
end
