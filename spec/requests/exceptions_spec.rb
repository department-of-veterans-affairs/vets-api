# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'exceptions', type: :request do
  before do
    exceptions_controller = Class.new(ApplicationController) do
      def test_authentication
        head :ok
      end
    end
    stub_const('ExceptionsController', exceptions_controller)
    Rails.application.routes.draw do
      get '/test_authentication' => 'exceptions#test_authentication'
    end
  end

  after { Rails.application.reload_routes! }

  context 'authorization' do
    it 'renders json for not authorized' do
      get '/test_authentication'
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['errors'].first)
        .to eq(
          'title' => 'Not authorized',
          'detail' => 'Not authorized',
          'code' => '401',
          'status' => '401'
        )
    end
  end
end
