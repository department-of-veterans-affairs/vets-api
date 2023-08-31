# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'

describe ApplicationController, type: :controller do
  let(:scopes) { %w[system/claim.write] }

  controller do
    skip_before_action :authenticate

    def raise_not_found
      raise Common::Exceptions::ResourceNotFound.new(detail: 'The BGS server did not find the resource.')
    end

    def raise_unprocessable
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: 'Please try again after checking your input values.'
      )
    end

    def raise_service_error
      raise Common::Exceptions::ServiceError.new(detail: 'An external server is experiencing difficulty.')
    end
  end

  before do
    routes.draw do
      get 'raise_not_found' => 'anonymous#raise_not_found'
      get 'raise_unprocessable' => 'anonymous#raise_unprocessable'
      get 'raise_service_error' => 'anonymous#raise_service_error'
    end
  end

  it 'catches resource not found' do
    with_okta_user(scopes) do |auth_header|
      # Following the normal headers: auth_header pattern fails due to
      # this rspec bug: https://github.com/rspec/rspec-rails/issues/1655
      # This is the recommended workaround from that issue thread.
      request.headers.merge!(auth_header)

      get :raise_not_found

      expect(response).to have_http_status(:not_found)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Resource not found')
      expect(parsed_body['errors'][0]['detail']).to eq('The BGS server did not find the resource.')
    end
  end

  it 'catches an unknown service error' do
    with_okta_user(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_service_error

      expect(response).to have_http_status(:server_error)
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Unknown Service Error')
      expect(parsed_body['errors'][0]['detail']).to eq('An external server is experiencing difficulty.')
    end
  end

  it 'catches an unprocessable entity' do
    with_okta_user(scopes) do |auth_header|
      request.headers.merge!(auth_header)

      get :raise_unprocessable

      expect(response).to have_http_status(:unprocessable_entity)
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['errors'].size).to eq(1)
      expect(parsed_body['errors'][0]['title']).to eq('Unprocessable Entity')
      expect(parsed_body['errors'][0]['detail']).to eq('Please try again after checking your input values.')
    end
  end
end
