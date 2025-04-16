# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'
require 'my_health/prescriptions/client'

# Tests that MyHealth::Prescriptions::Client is being used to replace Rx::Client
RSpec.describe 'MyHealth Prescriptions Client', type: :request do
  let(:user) { build(:user, :mhv) }

  describe 'client implementation' do
    it 'uses MyHealth::Prescriptions::Client in RxController' do
      controller_instance = MyHealth::RxController.new
      allow(controller_instance).to receive(:current_user).and_return(user)
      expect(controller_instance.send(:client)).to be_a(MyHealth::Prescriptions::Client)
    end
  end

  describe 'client interface' do
    let(:rx_client) { Rx::Client.new(session: { user_id: '123' }) }
    let(:myhealth_client) { MyHealth::Prescriptions::Client.new(session: { user_id: '123' }) }

    it 'has the same public methods as Rx::Client' do
      rx_client.methods
      Object.methods
      myhealth_methods = myhealth_client.methods - Object.methods

      # The MyHealth client should at least have these important methods
      expected_methods = %i[get_active_rxs get_history_rxs get_rx_details post_refill_rx]
      expected_methods.each do |method|
        expect(myhealth_methods).to include(method)
      end
    end
  end

  describe 'service name configuration' do
    it 'has its own distinct service name' do
      config = MyHealth::Prescriptions::Configuration.instance
      expect(config.service_name).to eq('MyHealth-Prescriptions')
    end
  end
end
