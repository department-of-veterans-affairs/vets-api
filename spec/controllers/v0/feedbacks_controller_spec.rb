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

  before do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @request.env["CONTENT_TYPE"] = "application/json"
  end

  it 'responds with 201' do
    post :create, params
    expect(response).to have_http_status(:created)
    expect(response.header['Content-Type']).to include('application/json')
  end
  
  it 'responds with param error when required params are missing'
  it 'responds with param error when required params are null or empty'
end