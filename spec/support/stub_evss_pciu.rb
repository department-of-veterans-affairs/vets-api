# frozen_string_literal: true

require 'evss/pciu/service'

def stub_evss_pciu(user)
  email_response = VCR.use_cassette('evss/pciu/email') do
    EVSS::PCIU::Service.new(user).get_email_address
  end

  phone_response = VCR.use_cassette('evss/pciu/primary_phone') do
    EVSS::PCIU::Service.new(user).get_primary_phone
  end

  alternate_phone_response = VCR.use_cassette('evss/pciu/alternate_phone') do
    EVSS::PCIU::Service.new(user).get_alternate_phone
  end

  allow_any_instance_of(EVSS::PCIU::Service).to receive(:get_email_address).and_return(email_response)
  allow_any_instance_of(EVSS::PCIU::Service).to receive(:get_primary_phone).and_return(phone_response)
  allow_any_instance_of(EVSS::PCIU::Service).to receive(:get_alternate_phone).and_return(alternate_phone_response)

  [email_response, phone_response, alternate_phone_response]
end
