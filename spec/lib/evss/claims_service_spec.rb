# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ClaimsService do
  let(:current_user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
    {"va_eauth_csid"=>"DSLogon", "va_eauth_authenticationmethod"=>"DSLogon", "va_eauth_pnidtype"=>"SSN", "va_eauth_assurancelevel"=>"3", "va_eauth_firstName"=>"WESLEY", "va_eauth_lastName"=>"FORD", "va_eauth_issueinstant"=>"2017-12-07T00:55:09Z", "va_eauth_dodedipnid"=>"1007697216", "va_eauth_birlsfilenumber"=>"796043735", "va_eauth_pid"=>"600061742", "va_eauth_pnid"=>"796043735", "va_eauth_birthdate"=>"1986-05-06T00:00:00+00:00", "va_eauth_authorization"=>"{\"authorizationResponse\":{\"status\":\"VETERAN\",\"idType\":\"SSN\",\"id\":\"796043735\",\"edi\":\"1007697216\",\"firstName\":\"WESLEY\",\"lastName\":\"FORD\",\"birthDate\":\"1986-05-06T00:00:00+00:00\"}}"}
  end

  let(:claims_service) { described_class.new(auth_headers) }

  subject { claims_service }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims' do
      binding.pry; fail
      VCR.use_cassette('evss/claims/claims') do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should post a 5103 waiver' do
      VCR.use_cassette('evss/claims/set_5103_waiver') do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end
  end
end
