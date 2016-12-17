# frozen_string_literal: true
require 'rails_helper'
require 'evss/mhvcf/client'

describe 'evss mhvcf' do
  subject(:client) { EVSS::MHVCF::Client.new }
  let(:user) { build(:user) }

  # This is a useful spec to test negative case of SSL certificate being invalid.
  it 'gets inflight forms', :vcr do
    expect(client.user(user).get_forms).to eq({})

    # raise_error do |error|
    #   expect(error).to be_a(Common::Client::Errors::ClientError)
    #   expect(error.cause).to be_a(Faraday::SSLError)
    #   ssl_error = 'SSL_connect returned=1 errno=0 state=error: certificate verify failed'
    #   expect(error.cause.message).to eq(ssl_error)
    # end
  end
end
