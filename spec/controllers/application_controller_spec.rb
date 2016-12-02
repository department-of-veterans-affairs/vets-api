# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    JSON_ERROR = {
      'errorCode' => 139, 'developerMessage' => '', 'message' => 'Prescription is not Refillable'
    }.freeze

    def record_not_found
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end

    def other_error
      raise Common::Exceptions::BackendServiceException, 'RX139'
    end

    def client_connection_failed
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end
  end

  context 'RecordNotFound' do
    subject { JSON.parse(response.body)['errors'].first }
    before(:each) { routes.draw { get 'record_not_found' => 'anonymous#record_not_found' } }
    let(:keys_for_all_env) { %w(title detail code status) }

    context 'with Rails.env.test or Rails.env.development' do
      it 'renders json object with developer attributes' do
        get :record_not_found
        expect(subject.keys).to eq(keys_for_all_env)
      end
    end

    context 'with Rails.env.production' do
      it 'renders json error with production attributes' do
        allow(Rails)
          .to(receive(:env))
          .and_return(ActiveSupport::StringInquirer.new('production'))

        get :record_not_found
        expect(subject.keys)
          .to eq(keys_for_all_env)
      end
    end
  end

  context 'BackendServiceErrorError' do
    subject { JSON.parse(response.body)['errors'].first }
    before(:each) { routes.draw { get 'other_error' => 'anonymous#other_error' } }
    let(:keys_for_production) { %w(title detail code status) }
    let(:keys_for_development) { keys_for_production + ['meta'] }

    context 'with Rails.env.test or Rails.env.development' do
      it 'renders json object with developer attributes' do
        get :other_error
        expect(subject.keys).to eq(keys_for_development)
      end
    end

    context 'with Rails.env.production' do
      it 'renders json error with production attributes' do
        allow(Rails)
          .to(receive(:env))
          .and_return(ActiveSupport::StringInquirer.new('production'))

        get :other_error
        expect(subject.keys)
          .to eq(keys_for_production)
      end
    end
  end

  context 'ConnectionFailed Error' do
    before(:each) do
      routes.draw do
        get 'client_connection_failed' => 'anonymous#client_connection_failed'
        get 'client_connection_failed_no_sentry' => 'anonymous#client_connection_failed_no_sentry'
      end
    end

    it 'makes a call to sentry when there is cause' do
      allow_any_instance_of(Rx::Client)
        .to receive(:connection).and_raise(Faraday::ConnectionFailed, 'some message')
      expect(Raven).to receive(:capture_exception).once
      ClimateControl.modify SENTRY_DSN: 'T' do
        get :client_connection_failed
      end
      expect(JSON.parse(response.body)['errors'].first['title'])
        .to eq('Service unavailable')
    end
  end
end
