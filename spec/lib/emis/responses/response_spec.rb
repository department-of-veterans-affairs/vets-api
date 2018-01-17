# frozen_string_literal: true
require 'rails_helper'
require 'emis/responses/response'
require 'emis/errors/service_error'

describe EMIS::Responses::Response do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/errorResponse.xml')) }
  let(:response) { EMIS::Responses::Response.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe '#error' do
    context 'when a response contains an error' do
      it 'returns the  error' do
        e = EMIS::Errors::ServiceError.new('MIS-ERR-005 EDIPI_BAD_FORMAT EDIPI incorrectly formatted')
        expect(response.error).to eq(e)
      end
    end
  end
end
