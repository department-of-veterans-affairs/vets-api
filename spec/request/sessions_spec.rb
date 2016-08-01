require "rails_helper"

RSpec.describe "Sessions API", type: :request do
  context "when not logged in" do
    it "formats a SAML request and redirects to ID.me" do
    end
  end

  context "when logged in" do
    it "returns a JSON user profile" do
    end
  end
end
