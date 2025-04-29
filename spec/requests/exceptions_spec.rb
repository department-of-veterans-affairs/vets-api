# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'exceptions', type: :request do
  context 'authorization' do
    it 'renders json for not authorized' do
      get '/v0/user'
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

  context 'routing' do
    %i[get post put patch delete].each do |method|
      it "renders json for routing errors on #{method}" do
        send(method, '/an_unknown_route')
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['errors'].first)
          .to eq(
            'title' => 'Not found',
            'detail' => 'There are no routes matching your request: an_unknown_route',
            'code' => '411',
            'status' => '404'
          )
      end
    end
  end
end
