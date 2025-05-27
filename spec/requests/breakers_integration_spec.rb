# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Breakers Integration', type: :request do
  before do
    breakers_configuration = Class.new(Common::Client::Configuration::REST) do
      def base_path
        'http://example.com'
      end

      def service_name
        'breakers'
      end

      def breakers_error_threshold
        80
      end

      def connection
        Faraday.new(base_path) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.response :raise_custom_error, error_prefix: service_name
        end
      end
    end
    stub_const('BreakersConfiguration', breakers_configuration)

    breakers_client = Class.new(Common::Client::Base) do
      configuration BreakersConfiguration

      def client_route
        perform(:get, '/some-route', nil)
      end

      Breakers.client.services << BreakersConfiguration.instance.breakers_service
    end
    stub_const('BreakersClient', breakers_client)

    breakers_controller = Class.new(ApplicationController) do
      skip_before_action :authenticate

      def breakers_test
        BreakersClient.new.client_route
        head :ok
      end
    end
    stub_const('BreakersController', breakers_controller)

    Rails.application.routes.draw do
      get '/breakers_test' => 'breakers#breakers_test'
    end
  end

  after do
    Rails.application.reload_routes!
    Breakers.client.services.delete(BreakersConfiguration.instance.breakers_service)
  end

  context 'integration test for breakers' do
    it 'raises a breakers exception failure rate' do
      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)

      stub_request(:get, 'http://example.com/some-route').to_return(status: 200)
      20.times do
        response = get '/breakers_test'
        expect(response).to eq(200)
      end

      stub_request(:get, 'http://example.com/some-route').to_return(status: 500)
      80.times do
        response = get '/breakers_test'
        expect(response).to eq(500)
      end

      expect do
        get '/breakers_test'
      end.to trigger_statsd_increment('api.external_http_request.breakers.skipped', times: 1, value: 1)

      response = get '/breakers_test'
      expect(response).to eq(503)

      Timecop.freeze(now)
      stub_request(:get, 'http://example.com/some-route').to_return(status: 200)
      response = get '/breakers_test'
      expect(response).to eq(200)
      Timecop.return
    end
  end
end
