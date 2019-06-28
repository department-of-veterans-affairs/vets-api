# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::ZipcodeRatesController, type: :controller do
  let(:client) { instance_double('GI::Client') }
  before(:each) do
    controller.instance_variable_set(:@client, client)
  end
  describe 'zipcode rates' do
    {
      'show' => :get_zipcode_rate
    }.each do |controller_method, client_method|
      it "\##{controller_method} calls client method #{client_method}" do
        allow(client).to receive(client_method)
        get controller_method, params: { id: '123' }
        expect(client).to have_received(client_method).with('id' => '123')
      end
    end
  end
end
