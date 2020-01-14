# frozen_string_literal: true

require "rails_helper"

describe AppealsApi::V1::DecisionReview::ContestableIssuesController, type: :request do
  describe "#index" do
    it do
      get(
        "/services/appeals/v1/decision_review/contestable_issues",
        headers: {
          "veteranId" => "123456789",
          "receiptDate" => Time.zone.today.strftime("%F")
        }
      )
      json = JSON.parse(response.body)
      expect(json).to eq ""
      expect(json).not_to eq(
        "errors" => [{ "code" => "401", "detail" => "Not authorized", "status" => "401", "title" => "Not authorized" }]
        )
      expect(response).to have_http_status(:ok)
    end
  end
end
