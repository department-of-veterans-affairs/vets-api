# frozen_string_literal: true

describe AppealsApi::V1::ContestableIssuesController, type: :request do
  describe '#index' do
    it do
      get(
        "/services/appeals/v1/decision_review/contestable_issues",
        headers: {
          "veteranId" => "123456789",
          "receiptDate" => Time.zone.today.strftime("%F")
        }
      )
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an Array
    end
  end
end
