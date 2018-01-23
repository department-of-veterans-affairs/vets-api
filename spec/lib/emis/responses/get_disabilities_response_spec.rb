# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_disabilities_response'

describe EMIS::Responses::GetDisabilitiesResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getDisabilitiesResponse.xml')) }
  let(:response) { EMIS::Responses::GetDisabilitiesResponse.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'gives the disability percent' do
        expect(response.items.first.disability_percent).to eq(30.0)
      end

      it 'gives the pay amount' do
        expect(response.items.first.pay_amount).to eq(728.0)
      end
    end
  end
end
