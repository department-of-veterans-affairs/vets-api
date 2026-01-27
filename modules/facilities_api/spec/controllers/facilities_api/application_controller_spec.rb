# frozen_string_literal: true

require 'rails_helper'

# Dummy serializer for testing
class TestSerializer
  def initialize(data, _options = {})
    @data = data
  end

  def to_json(*_args)
    { data: @data }.to_json
  end
end

RSpec.describe FacilitiesApi::ApplicationController, type: :controller do
  controller do
    def test_populated_array
      render_json(TestSerializer, {}, %w[item1 item2])
    end

    def test_empty_array
      render_json(TestSerializer, {}, [])
    end

    # Mock resource_path method required by meta_pagination
    def resource_path(params)
      "/test_path?#{params.to_query}"
    end
  end

  before do
    routes.draw do
      get 'test_populated_array' => 'facilities_api/application#test_populated_array'
      get 'test_empty_array' => 'facilities_api/application#test_empty_array'
    end
  end

  describe '#render_json' do
    context 'with a populated array' do
      it 'renders the array without error' do
        get :test_populated_array
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to eq(%w[item1 item2])
      end
    end

    context 'with an empty array' do
      it 'raises RecordNotFound exception for blank arrays' do
        # When a blank array is passed to render_json, it raises RecordNotFound
        # The ExceptionHandling concern catches it and returns a 404 response
        get :test_empty_array
        # Verify that a 404 status is returned (due to the RecordNotFound exception)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
