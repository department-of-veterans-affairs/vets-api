# frozen_string_literal: true

describe AppealsApi::Docs::V1::DocsController, type: :request do
  describe "#decision_reviews" do
    let(:decision_reviews_docs) { '/services/appeals/docs/v1/decision_reviews' }
    it "should successfully return openapi spec" do
      get decision_reviews_docs
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["openapi"]).to eq("3.0.0")
    end
    describe "/higher_level_reviews documentation" do
      before(:each) do
        get decision_reviews_docs
      end
      let(:hlr_doc) do
        json = JSON.parse(response.body)
        json["paths"]["/higher_level_reviews"]
      end
      it "should have POST" do
        expect(hlr_doc).to include("post")
      end
    end
    describe "/intake_statuses/{uuid} documentation" do
      before(:each) do
        get decision_reviews_docs
      end
      let(:hlr_intake_status_doc) do
        json = JSON.parse(response.body)
        json["paths"]["/intake_statuses/{uuid}"]
      end
      it "should have GET" do
        expect(hlr_intake_status_doc).to include("get")
      end
    end
    describe "/higher_level_reviews/{uuid} documentation" do
      before(:each) do
        get decision_reviews_docs
      end
      let(:hlr_intake_status_doc) do
        json = JSON.parse(response.body)
        json["paths"]["/higher_level_reviews/{uuid}"]
      end
      it "should have GET" do
        expect(hlr_intake_status_doc).to include("get")
      end
    end
  end
end
