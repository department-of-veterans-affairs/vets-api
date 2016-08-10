require "rails_helper"

RSpec.describe "SAML Metadata", type: :request do
  it "Provides XML SAML metadata" do
    get "/saml/metadata"
    assert_response :success

    xml = Nokogiri::XML(response.body)

    entity_id = xml.at_xpath("//md:EntityDescriptor/@entityID", "md" => "urn:oasis:names:tc:SAML:2.0:metadata")
    expect(entity_id.value).to eq(ENV["SAML_ISSUER"])
  end
end
