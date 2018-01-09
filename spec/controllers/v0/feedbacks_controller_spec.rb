# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FeedbacksController, type: :controller do
  let(:params) do
    {
      description: 'I liked this page',
      target_page: '/some/example/page.html',
      owner_email: 'example@email.com'
    }
  end
  let(:missing_params) { params.select { |k, _v| k != :target_page } }
  let(:empty_params) { params.merge(description: '') }

  before do
    @request.env['HTTP_ACCEPT'] = 'application/json'
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  it 'responds with 202' do
    post :create, params
    expect(response).to have_http_status(:accepted)
    expect(response.header['Content-Type']).to include('application/json')
  end

  it 'responds with param error when required params are missing' do
    post :create, missing_params
    expect(response).to have_http_status(:bad_request)
    expect(response.body).to include('The required parameter \\"target_page\\", is missing')
  end

  it 'responds with param error when required params are null or empty' do
    post :create, empty_params
    expect(response).to have_http_status(:bad_request)
    expect(response.body).to include('The required parameter \\"description\\", is missing')
  end
end
