# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
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
end
