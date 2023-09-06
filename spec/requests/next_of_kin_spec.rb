require 'rails_helper'

RSpec.describe "NextOfKin", type: :request do
  describe "GET /create" do
    it "returns http success" do
      get "/next_of_kin/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/next_of_kin/show"
      expect(response).to have_http_status(:success)
    end
  end

end
