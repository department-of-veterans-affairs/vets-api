# frozen_string_literal: true
require "rails_helper"
require_dependency "evss/documents_service"

describe EVSS::DocumentsService do
  let(:vaafi_headers) do
    {
      "va_eauth_pnidtype" => "SSN",
      "va_eauth_csid" => "DSLogon",
      "va_eauth_firstName" => "Jane",
      "va_eauth_lastName" => "Doe",
      "va_eauth_authenticationauthority" => "eauth",
      "iv-user" => "dslogoneauthuser",
      "va_eauth_emailAddress" => "jane.doe@va.gov",
      "va_eauth_birthdate" => "1999-10-09T08:06:12-04:00",
      "va_eauth_pid" => "123456789",
      "va_eauth_issueinstant" => "2015-04-17T14:52:48Z",
      "va_eauth_dodedipnid" => "1105051936",
      "va_eauth_middleName" => "A",
      "va_eauth_authenticationmethod" => "DSLogon",
      "va_eauth_assurancelevel" => "2"
    }
  end

  subject { described_class.new(vaafi_headers) }

  context "with headers" do
    it "should get claims" do
      VCR.use_cassette("evss/documents/all_documents") do
        response = subject.all_documents
        expect(response).to be_success
      end
    end
  end
end
