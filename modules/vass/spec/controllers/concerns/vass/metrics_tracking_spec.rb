# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::MetricsTracking, type: :controller do
  controller(ActionController::Base) do
    include Vass::MetricsTracking

    def test_success
      render json: { status: 'ok' }, status: :ok
      track_success(Vass::MetricsConstants::APPOINTMENTS_CREATE)
    end

    def test_failure
      render json: { status: 'error' }, status: :bad_gateway
      track_failure(Vass::MetricsConstants::APPOINTMENTS_CREATE, error_type: 'TestError')
    end

    def test_infrastructure
      track_infrastructure_metric(Vass::MetricsConstants::SESSION_OTP_EXPIRED)
      render json: { status: 'ok' }, status: :ok
    end

    def test_with_additional_tags
      track_success(Vass::MetricsConstants::APPOINTMENTS_CREATE, additional_tags: { cohort: 'morning' })
      render json: { status: 'ok' }, status: :ok
    end
  end

  before do
    routes.draw do
      get 'test_success' => 'anonymous#test_success'
      post 'test_failure' => 'anonymous#test_failure'
      get 'test_infrastructure' => 'anonymous#test_infrastructure'
      get 'test_with_additional_tags' => 'anonymous#test_with_additional_tags'
    end
  end

  describe '#track_success' do
    it 'increments success metric with correct tags' do
      expect(StatsD).to receive(:increment).with(
        'api.vass.controller.appointments.create.success',
        hash_including(
          tags: array_including(
            'service:vass',
            'endpoint:test_success',
            'http_method:GET',
            'http_status:200'
          )
        )
      )

      get :test_success
      expect(response).to have_http_status(:ok)
    end

    it 'includes additional tags when provided' do
      expect(StatsD).to receive(:increment).with(
        'api.vass.controller.appointments.create.success',
        hash_including(
          tags: array_including(
            'service:vass',
            'endpoint:test_with_additional_tags',
            'http_method:GET',
            'http_status:200',
            'cohort:morning'
          )
        )
      )

      get :test_with_additional_tags
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#track_failure' do
    it 'increments failure metric with error type tag' do
      expect(StatsD).to receive(:increment).with(
        'api.vass.controller.appointments.create.failure',
        hash_including(
          tags: array_including(
            'service:vass',
            'endpoint:test_failure',
            'http_method:POST',
            'http_status:502',
            'error_type:TestError'
          )
        )
      )

      post :test_failure
      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe '#track_infrastructure_metric' do
    it 'increments infrastructure metric with service tag' do
      expect(StatsD).to receive(:increment).with(
        'api.vass.infrastructure.session.otp.expired',
        hash_including(
          tags: array_including('service:vass')
        )
      )

      get :test_infrastructure
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#build_metric_tags' do
    controller(ActionController::Base) do
      include Vass::MetricsTracking

      def test_build_tags
        tags = build_metric_tags(
          http_status: 200,
          error_type: 'SomeError',
          additional_tags: { key: 'value' }
        )
        render json: { tags: }, status: :ok
      end
    end

    before do
      routes.draw { get 'test_build_tags' => 'anonymous#test_build_tags' }
    end

    it 'builds tags with all components' do
      get :test_build_tags

      json_response = JSON.parse(response.body)
      tags = json_response['tags']

      expect(tags).to include('service:vass')
      expect(tags).to include('endpoint:test_build_tags')
      expect(tags).to include('http_method:GET')
      expect(tags).to include('http_status:200')
      expect(tags).to include('error_type:SomeError')
      expect(tags).to include('key:value')
    end
  end
end
