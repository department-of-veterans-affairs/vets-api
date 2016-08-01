require "rails_helper"

RSpec.describe "Sessions API", type: :request do
  context "when not logged in" do
    it "formats a SAML request and redirects to ID.me" do
      get "/v0/sessions/new"
      assert_response :redirect

      saml_url = "https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest="
      expect(response.location).to include(saml_url)
    end

    it "creates a session from a valid SAML response" do
    end

    it "returns an error response from an invalid SAML response" do
    end

    it "redirects to login when requesting profile" do
      get "/v0/profile"
      assert_response :redirect
    end
  end

  context "when logged in" do
    it "returns a JSON user profile" do
    end
  end
end
