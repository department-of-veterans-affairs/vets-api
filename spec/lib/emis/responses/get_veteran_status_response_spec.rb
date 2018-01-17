# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_veteran_status_response'

describe EMIS::Responses::GetVeteranStatusResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getVeteranStatusResponse.xml')) }
  let(:response) { EMIS::Responses::GetVeteranStatusResponse.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'gives the title38 status code' do
        expect(response.items.first.title38_status_code).to eq('V4')
      end

      it 'indicates post 911 deployment' do
        expect(response.items.first.post911_deployment_indicator).to eq('Y')
      end

      it 'indicates post 911 combat' do
        expect(response.items.first.post911_combat_indicator).to eq('N')
      end

      it 'indicates pre 911 deployment' do
        expect(response.items.first.pre911_deployment_indicator).to eq('Y')
      end
    end
  end
end
