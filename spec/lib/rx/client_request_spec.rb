# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

# These tests are being added to test error handling added to the Rx::Client
# that impacts several endpoints spread across multiple engines and controllers.
# Unit testing on the Rx::Client proved inadequate because our error handling
# is deeply coupled with the ExceptionHandling module and controller behavior.
# Creating a mock controller to integration test the changes rather than test
# for every endpoint that uses the client. These tests use the get_history_rxs
# method but the behavior applies to all requests made within Rx::Client.
describe 'ClientRequestSpec', type: :request do
  before do
    klass = Class.new(ApplicationController) do
      skip_before_action :authenticate

      def index
        client = Rx::Client.new(session: { user_id: 123 })
        client.get_history_rxs
      end
    end
    stub_const('RxTestsController', klass)

    Rails.application.routes.draw do
      get '/rx_test_index', to: 'rx_tests#index'
    end
  end

  after { Rails.application.reload_routes! }

  describe 'error handling' do
    it 'converts 400 optimistic locking errors to 409' do
      VCR.use_cassette('rx_client/prescriptions/gets_optimistic_locking_error') do
        get '/rx_test_index'
        expect(response).to have_http_status(:conflict)
      end
    end

    it 'converts Faraday::TimeouError to 408' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)

      get '/rx_test_index'
      expect(response).to have_http_status(:request_timeout)
    end
  end
end
