require "rails_helper"

RSpec.describe V0::SessionsController, type: :controller do
  context "when not logged in" do
    it "formats a SAML request and redirects to ID.me" do
      get :new
      assert_response :redirect

      saml_url = "https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest="
      expect(response.location).to include(saml_url)
    end

    it "creates a session from a valid SAML response" do
    end

    it "returns an error response from an invalid SAML response" do
    end

    it "redirects to login when requesting profile" do
      get :show
      assert_response :redirect
    end
  end

  context "when logged in" do
    before(:each) do
      session[:user] = {
        "name" => "someUUID",
        "attributes" => {
          "fname" => ["Firstname"],
          "lname" => ["Lastname"],
          "zip" => "02139",
          "email" => ["fedshauni@gmail.com"],
          "uuid" => ["someUUID"]
        }
      }
    end

    it "returns a JSON user profile" do
      get :show
      assert_response :success

      json = JSON.parse(response.body)

      expect(json["uuid"].first).to eq("someUUID")
      expect(json["first_name"].first).to eq("Firstname")
    end
  end
end
