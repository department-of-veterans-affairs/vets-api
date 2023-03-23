# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V1::BaseController, type: :controller do
  let(:user) { create(:user) }
  let(:id) { '987654' }

  controller do
    skip_before_action :authenticate
    skip_before_action :authorize

    def record_not_found
      raise Common::Exceptions::RecordNotFound, '987654'
    end

    def service_error
      raise Common::Exceptions::BackendServiceException.new('VAOS_502', { source: 'Klass' })
    end
  end

  before do
    controller.instance_variable_set(:@current_user, user)

    routes.draw do
      get 'record_not_found' => 'vaos/v1/base#record_not_found'
      get 'service_error' => 'vaos/v1/base#service_error'
    end
  end

  context 'with a RecordNotFound error' do
    it 'renders json object with developer attributes' do
      get :record_not_found, params: { id: }
      expected_body = {
        'id' => id,
        'issue' => [
          {
            'code' => '404',
            'details' => {
              'text' => 'The record identified by 987654 could not be found'
            },
            'diagnostics' => nil,
            'severity' => 'error'
          }
        ],
        'resourceType' => 'Base',
        'text' => {
          'div' => '<div xmlns="http://www.w3.org/1999/xhtml"><p>{:text=>"' \
                   "The record identified by #{id} could not be found\"}</p></div>",
          'status' => 'generated'
        }
      }
      expect(JSON.parse(response.body)).to eq(expected_body)
    end
  end

  context 'with a BackendServiceError error' do
    it 'renders json object with developer attributes' do
      get :service_error, params: { id: }
      expected_body = {
        'id' => id,
        'issue' => [
          {
            'code' => 'VAOS_502',
            'details' => {
              'text' => 'Received an an invalid response from the upstream server'
            },
            'diagnostics' => 'Klass',
            'severity' => 'error'
          }
        ],
        'resourceType' => 'Base',
        'text' => {
          'div' => '<div xmlns="http://www.w3.org/1999/xhtml"><p>{:text=>"' \
                   'Received an an invalid response from the upstream server"}</p></div>',
          'status' => 'generated'
        }
      }
      expect(JSON.parse(response.body)).to eq(expected_body)
    end
  end
end
