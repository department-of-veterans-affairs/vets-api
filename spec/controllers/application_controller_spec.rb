# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'
require 'lib/sentry_logging_spec_helper'

RSpec.describe ApplicationController, type: :controller do
  it_behaves_like 'a sentry logger'
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

  describe '#clear_saved_form' do
    let(:user) { create(:user) }

    subject do
      controller.clear_saved_form(form_id)
    end

    context 'with a saved form' do
      let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }
      let(:form_id) { in_progress_form.form_id }

      context 'without a current user' do
        it "shouldn't delete the form" do
          subject
          expect(model_exists?(in_progress_form)).to be(true)
        end
      end

      context 'with a current user' do
        before do
          controller.instance_variable_set(:@current_user, user)
        end

        it 'should delete the form' do
          subject
          expect(model_exists?(in_progress_form)).to be(false)
        end
      end
    end

    context 'without a saved form' do
      let(:form_id) { 'foo' }

      before do
        controller.instance_variable_set(:@current_user, user)
      end

      it 'should do nothing' do
        subject
      end
    end
  end

  context 'RecordNotFound' do
    subject { JSON.parse(response.body)['errors'].first }
    before(:each) { routes.draw { get 'record_not_found' => 'anonymous#record_not_found' } }
    let(:keys_for_all_env) { %w[title detail code status] }

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
    let(:keys_for_production) { %w[title detail code status] }
    let(:keys_for_development) { keys_for_production + ['meta'] }

    context 'with Rails.env.test or Rails.env.development' do
      it 'renders json object with developer attributes' do
        get :other_error
        expect(subject.keys).to eq(keys_for_production)
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
      expect(Raven).to receive(:extra_context).once.with(
        request_uuid: nil
      )
      # if current user is nil it means user is not signed in.
      expect(Raven).to receive(:tags_context).once.with(
        controller_name: 'anonymous',
        sign_in_method: 'not-signed-in'
      )
      # since user is not signed in this shouldnt get called.
      expect(Raven).not_to receive(:user_context)
      expect(Raven).to receive(:capture_exception).once
      with_settings(Settings.sentry, dsn: 'T') do
        get :client_connection_failed
      end
      expect(JSON.parse(response.body)['errors'].first['title'])
        .to eq('Service unavailable')
    end

    context 'signed in user' do
      let(:user) { create(:user) }
      before do
        controller.instance_variable_set(:@current_user, user)
      end

      it 'makes a call to sentry when there is cause' do
        allow_any_instance_of(Rx::Client)
          .to receive(:connection).and_raise(Faraday::ConnectionFailed, 'some message')
        expect(Raven).to receive(:extra_context).once.with(
          request_uuid: nil
        )
        # if authn_context is nil on current_user it means idme
        expect(Raven).to receive(:tags_context).once.with(
          controller_name: 'anonymous',
          sign_in_method: 'idme'
        )
        # since user IS signed in, this SHOULD get called
        expect(Raven).to receive(:user_context).with(
          uuid: user.uuid,
          authn_context: user.authn_context,
          loa: user.loa,
          mhv_icn: user.mhv_icn
        )
        expect(Raven).to receive(:capture_exception).once
        with_settings(Settings.sentry, dsn: 'T') do
          get :client_connection_failed
        end
        expect(JSON.parse(response.body)['errors'].first['title'])
          .to eq('Service unavailable')
      end
    end
  end
end
