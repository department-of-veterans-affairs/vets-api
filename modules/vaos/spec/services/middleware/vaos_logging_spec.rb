# frozen_string_literal: true

require 'rails_helper'
# require 'common/client/middleware/vaos_logging'

describe VAOS::Middleware::VaosLogging do
  subject(:client) do
    Faraday.new do |conn|
      conn.use :logging, type_key

      conn.adapter :test do |stub|
        stub.get('success') { [200, { 'Content-Type' => 'text/plain' }, response_data] }
        stub.post('success') { [200, { 'Content-Type' => 'text/plain' }, response_data] }
      end
    end
  end

  let(:type_key) { 'jalepeno' }
  let(:response_data) { 'poppers' }

  it 'is a temp test to check for failure' do
    expect('not nil').to be_nil
  end
end
