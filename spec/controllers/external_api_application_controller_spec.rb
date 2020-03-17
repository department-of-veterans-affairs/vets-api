# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalApiApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate
    def index
      render json: { 'test' => 'random data' }
    end
  end

  it 'does not set a CSRF token for GET requests' do
    get :index
    expect(response).to be_ok
    expect(cookies['X-CSRF-Token']).to be_nil
  end
end
