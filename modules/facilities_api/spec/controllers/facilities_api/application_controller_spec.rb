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

    # Mock resource_path method required by meta_pagination
    def resource_path(params)
      "/test_path?#{params.to_query}"
    end
  end

  before do
    routes.draw do
      get 'test_populated_array' => 'facilities_api/application#test_populated_array'
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
  end
end
