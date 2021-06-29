# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      render json: { message: 'Hello World!' }, status: :ok
    end
  end

  describe 'deactivate_endpoint' do
    context 'when a sunset date is passed' do
      it 'returns a 404' do
        allow(controller).to receive(:sunset_date).and_return(Date.yesterday)
        get :index
        expect(response.status).to eq(404)
      end
    end

    context 'when sunset date is nil or in the future' do
      it 'hits the endpoint' do
        allow(controller).to receive(:sunset_date).and_return(Date.tomorrow)
        get :index
        expect(response.status).to eq(200)
      end
    end
  end
end
