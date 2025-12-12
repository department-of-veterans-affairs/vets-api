# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe Chatbot::RequiresEdipi, type: :controller do
  controller(ActionController::Base) do
    include Chatbot::RequiresEdipi

    before_action :ensure_edipi_present

    def index
      render json: { data: ['ok'], meta: { sync_status: 'SUCCESS' } }
    end

    def show
      render json: { data: 'ok', meta: { sync_status: 'SUCCESS' } }
    end

    def create
      render json: { data: 'created', meta: { sync_status: 'SUCCESS' } }
    end

    private

    attr_reader :mpi_profile

    def icn
      '12345'
    end
  end

  before do
    routes.draw do
      get 'anonymous/index', to: 'anonymous#index'
      get 'anonymous/show', to: 'anonymous#show'
      post 'anonymous/create', to: 'anonymous#create'
    end
  end

  describe '#ensure_edipi_present' do
    context 'when mpi profile includes an edipi' do
      let(:profile) { OpenStruct.new(edipi: 'ABC123') }

      it 'allows the request to continue for index' do
        controller.instance_variable_set(:@mpi_profile, profile)

        get :index

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']).to eq(['ok'])
      end

      it 'allows the request to continue for show' do
        controller.instance_variable_set(:@mpi_profile, profile)

        get :show

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']).to eq('ok')
      end
    end

    context 'when mpi profile is missing an edipi' do
      let(:profile) { OpenStruct.new(edipi: nil) }

      it 'returns an empty array for index' do
        controller.instance_variable_set(:@mpi_profile, profile)

        get :index

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']).to eq([])
        expect(body['meta']).to eq('sync_status' => 'SUCCESS')
      end

      it 'returns nil data for show' do
        controller.instance_variable_set(:@mpi_profile, profile)

        get :show

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']).to be_nil
        expect(body['meta']).to eq('sync_status' => 'SUCCESS')
      end
    end

    context 'when mpi profile cannot be resolved' do
      it 'renders an empty payload' do
        controller.instance_variable_set(:@mpi_profile, nil)

        get :index

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']).to eq([])
      end
    end

    context 'when action is not supported' do
      it 'raises an argument error' do
        controller.instance_variable_set(:@mpi_profile, nil)

        expect do
          post :create
        end.to raise_error(ArgumentError, /Unsupported action/)
      end
    end
  end
end
