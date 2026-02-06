# frozen_string_literal: true

require 'rails_helper'
require 'rx/client' # used to stub Rx::Client in tests

RSpec.describe ApplicationController, type: :controller do
  controller do
    attr_reader :payload

    skip_before_action :authenticate, except: %i[test_authentication test_logging]

    JSON_ERROR = {
      'errorCode' => 139, 'developerMessage' => '', 'message' => 'Prescription is not Refillable'
    }.freeze

    def not_authorized
      raise Pundit::NotAuthorizedError
    end

    def unauthorized
      raise Common::Exceptions::Unauthorized
    end

    def routing_error
      raise Common::Exceptions::RoutingError
    end

    def forbidden
      raise Common::Exceptions::Forbidden
    end

    def test_logging
      Rails.logger.info sso_logging_info
    end

    def breakers_outage
      Rx::Configuration.instance.breakers_service.begin_forced_outage!
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end

    def record_not_found
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end

    def other_error
      raise Common::Exceptions::BackendServiceException, 'RX139'
    end

    def common_error_with_warning_sentry
      raise Common::Exceptions::BackendServiceException, 'VAOS_409A'
    end

    def client_connection_failed
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end

    def test_authentication
      head :ok
    end

    def append_info_to_payload(payload)
      super
      @payload = payload
    end
  end

  before do
    routes.draw do
      get 'test_logging' => 'anonymous#test_logging'
      get 'not_authorized' => 'anonymous#not_authorized'
      get 'unauthorized' => 'anonymous#unauthorized'
      get 'routing_error' => 'anonymous#routing_error'
      get 'forbidden' => 'anonymous#forbidden'
      get 'breakers_outage' => 'anonymous#breakers_outage'
      get 'common_error_with_warning_sentry' => 'anonymous#common_error_with_warning_sentry'
      get 'record_not_found' => 'anonymous#record_not_found'
      get 'other_error' => 'anonymous#other_error'
      get 'client_connection_failed' => 'anonymous#client_connection_failed'
      get 'client_connection_failed_no_sentry' => 'anonymous#client_connection_failed_no_sentry'
      get 'test_authentication' => 'anonymous#test_authentication'
    end
  end

  describe 'a sentry logger' do
    subject { class_instance }

    let(:class_instance) { described_class.new }
    let(:exception) { StandardError.new }

    context 'with SENTRY_DSN set' do
      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      describe '#log_message_to_sentry' do
        it 'logs to Sentry' do
          expect(Sentry).to receive(:set_tags)
          expect(Sentry).to receive(:set_extras)
          expect(Sentry).to receive(:capture_message)
          subject.log_message_to_sentry('blah', :error, { extra: 'context' }, tags: 'tagging')
        end
      end

      describe '#log_message_to_rails' do
        it 'error logs to Rails logger' do
          expect(Rails.logger).to receive(:error).with(/blah/).with(/context/)
          subject.log_message_to_rails('blah', :error, { extra: 'context' })
        end
      end

      describe '#log_exception_to_sentry' do
        it 'logs to Sentry' do
          expect(Sentry).to receive(:capture_exception).with(exception, level: 'error').once
          subject.log_exception_to_sentry(exception)
        end
      end

      describe '#log_exception_to_rails' do
        it 'warn logs to Rails logger' do
          expect(Rails.logger).to receive(:error).with(exception)
          subject.log_exception_to_rails(exception)
        end
      end
    end

    context 'without SENTRY_DSN set' do
      describe '#log_message_to_sentry' do
        it 'warn logs to Rails logger' do
          expect(Rails.logger).to receive(:warn).with(/blah/).with(/context/)
          subject.log_message_to_sentry('blah', :warn, { extra: 'context' }, tags: 'tagging')
        end

        it 'does not log to Sentry' do
          expect(Sentry).to receive(:capture_exception).exactly(0).times
          subject.log_message_to_sentry('blah', :warn, { extra: 'context' }, tags: 'tagging')
        end
      end

      describe '#log_exception_to_sentry' do
        it 'error logs to Rails logger' do
          expect(Rails.logger).to receive(:error).with("#{exception.message}.")
          subject.log_exception_to_sentry(exception)
        end

        it 'does not log to Sentry' do
          expect(Sentry).to receive(:capture_exception).exactly(0).times
          subject.log_exception_to_sentry(exception)
        end
      end
    end
  end

  describe 'SharedLogging (Rails logger routing)' do
    subject { described_class.new }

    describe '#log_message_to_rails' do
      it 'routes info level to Rails.logger.info with formatted context' do
        expect(Rails.logger).to receive(:info).with('hello : {:foo=>"bar"}')
        subject.log_message_to_rails('hello', 'info', { foo: 'bar' })
      end

      it 'routes warn level to Rails.logger.warn' do
        expect(Rails.logger).to receive(:warn).with('warn-only')
        subject.log_message_to_rails('warn-only', 'warn', {})
      end

      it 'falls back unknown level to Rails.logger.error' do
        expect(Rails.logger).to receive(:error).with('unknown')
        subject.log_message_to_rails('unknown', 'unknown', {})
      end

      it "maps 'warning' to Rails.warn level" do
        expect(Rails.logger).to receive(:warn).with('legacy-warning')
        subject.log_message_to_rails('legacy-warning', 'warning', {})
      end

      it 'defaults nil message to placeholder' do
        expect(Rails.logger).to receive(:info).with('[No Message Provided]')
        subject.log_message_to_rails(nil, 'info', {})
      end

      it 'defaults empty message to placeholder and keeps context' do
        expect(Rails.logger).to receive(:info).with('[No Message Provided] : {:foo=>"bar"}')
        subject.log_message_to_rails('', 'info', { foo: 'bar' })
      end

      it 'handles nil extra_context safely' do
        expect(Rails.logger).to receive(:info).with('test message')
        subject.log_message_to_rails('test message', 'info', nil)
      end

      it 'handles integer extra_context safely' do
        expect(Rails.logger).to receive(:info).with('test message : 42')
        subject.log_message_to_rails('test message', 'info', 42)
      end

      it 'handles custom object extra_context safely' do
        custom_obj = Object.new
        expect(Rails.logger).to receive(:info).with("test message : #{custom_obj}")
        subject.log_message_to_rails('test message', 'info', custom_obj)
      end
    end

    describe '#log_exception_to_rails' do
      it 'logs at error level by default' do
        ex = StandardError.new('boom')
        expect(Rails.logger).to receive(:error).with(anything)
        subject.log_exception_to_rails(ex)
      end

      it 'logs at specified level (warn)' do
        ex = RuntimeError.new('oops')
        expect(Rails.logger).to receive(:warn).with(anything)
        subject.log_exception_to_rails(ex, 'warn')
      end

      it 'falls back unknown level to error when logging exceptions' do
        ex = ArgumentError.new('bad')
        expect(Rails.logger).to receive(:error).with(anything)
        subject.log_exception_to_rails(ex, 'unknown')
      end

      it 'logs BackendServiceException with key:value error details' do
        ex = Common::Exceptions::BackendServiceException.new('RX139', { code: 'RX139', detail: 'x' })
        # Expect the final Rails.logger.error call with message and hash arguments
        expect(Rails.logger).to receive(:error).with(
          a_string_including('BackendServiceException'),
          hash_including(:title, :detail, :code, :status, :error_backtrace)
        )
        subject.log_exception_to_rails(ex, 'error')
      end

      it 'logs BackendServiceException safely when errors array is empty' do
        empty_errors_exception_class = Class.new(Common::Exceptions::BackendServiceException) do
          def errors
            [] # simulate unexpected empty error list
          end
        end
        ex = empty_errors_exception_class.new('RX139', { code: 'RX139', detail: 'x' })
        # Should still log the exception message and backtrace even with empty errors
        expect(Rails.logger).to receive(:error).with(
          a_string_including('BackendServiceException'),
          hash_including(:error_backtrace)
        )
        # Should not raise
        expect { subject.log_exception_to_rails(ex, 'error') }.not_to raise_error
      end

      it 'logs BackendServiceException safely when error attributes contain nil values' do
        nil_attrs_exception_class = Class.new(Common::Exceptions::BackendServiceException) do
          def errors
            [OpenStruct.new(attributes: { title: 'Error', detail: nil, code: '', status: 422 })]
          end
        end
        ex = nil_attrs_exception_class.new('RX139', { code: 'RX139', detail: 'x' })
        # Should filter out nil and empty values, keeping only valid attributes
        expect(Rails.logger).to receive(:error).with(
          a_string_including('BackendServiceException'),
          hash_including(:title, :status, :error_backtrace)
        )
        expect { subject.log_exception_to_rails(ex, 'error') }.not_to raise_error
      end

      it 'logs BackendServiceException safely when error attributes are all nil/empty' do
        all_empty_attrs_exception_class = Class.new(Common::Exceptions::BackendServiceException) do
          def errors
            [OpenStruct.new(attributes: { title: nil, detail: '', code: nil, status: '' })]
          end
        end
        ex = all_empty_attrs_exception_class.new('RX139', { code: 'RX139', detail: 'x' })
        # Should still log with just backtrace when all attributes are nil/empty
        expect(Rails.logger).to receive(:error).with(
          a_string_including('BackendServiceException'),
          hash_including(:error_backtrace)
        )
        expect { subject.log_exception_to_rails(ex, 'error') }.not_to raise_error
      end

      it 'handles nil exception gracefully by logging placeholder message' do
        expect(Rails.logger).to receive(:error).with('[No Exception Provided]')
        # Should not raise when exception is nil
        expect { subject.log_exception_to_rails(nil, 'error') }.not_to raise_error
      end
    end
  end

  describe 'Sentry Handling' do
    around do |example|
      with_settings(Settings.sentry, dsn: 'T') do
        example.run
      end
    end

    it 'does not log exceptions to sentry if Pundit::NotAuthorizedError' do
      expect(Sentry).not_to receive(:capture_exception).with(Pundit::NotAuthorizedError, { level: 'info' })
      expect(Sentry).not_to receive(:capture_message)
      get :not_authorized
    end

    it 'does log exceptions to sentry based on level identified in exception.en.yml' do
      expect(Sentry).to receive(:capture_exception).with(
        Common::Exceptions::BackendServiceException,
        { level: 'warning' }
      )
      expect(Sentry).not_to receive(:capture_message)
      get :common_error_with_warning_sentry
    end

    it 'does not log to sentry if Breakers::OutageException' do
      expect(Sentry).not_to receive(:capture_exception)
      expect(Sentry).not_to receive(:capture_message)
      get :breakers_outage
    end

    it 'does not log to sentry if Common::Exceptions::Unauthorized' do
      expect(Sentry).not_to receive(:capture_exception)
      expect(Sentry).not_to receive(:capture_message)
      get :unauthorized
    end

    it 'does not log to sentry if Common::Exceptions::RoutingError' do
      expect(Sentry).not_to receive(:capture_exception)
      expect(Sentry).not_to receive(:capture_message)
      get :routing_error
    end

    it 'does not log to sentry if Common::Exceptions::Forbidden' do
      expect(Sentry).not_to receive(:capture_exception)
      expect(Sentry).not_to receive(:capture_message)
      get :forbidden
    end
  end

  describe 'Datadog tracing' do
    let(:active_span) do
      instance_double(Datadog::Tracing::Span)
    end

    it 'sets error state on spans for handled exceptions' do
      allow(Datadog::Tracing).to receive(:active_span).and_return(active_span)
      expect(active_span).to receive(:set_error).with(Common::Exceptions::BackendServiceException)
      get :common_error_with_warning_sentry
    end

    it 'does not set error state on spans for expected exceptions' do
      allow(Datadog::Tracing).to receive(:active_span).and_return(active_span)
      expect(active_span).not_to receive(:set_error)
      get :forbidden
    end
  end

  describe '#clear_saved_form' do
    subject do
      controller.clear_saved_form(form_id)
    end

    let(:user) { create(:user) }

    context 'with a saved form' do
      let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }
      let(:form_id) { in_progress_form.form_id }

      context 'without a current user' do
        it 'does not delete the form' do
          subject
          expect(model_exists?(in_progress_form)).to be(true)
        end
      end

      context 'with a current user' do
        before do
          controller.instance_variable_set(:@current_user, user)
        end

        it 'deletes the form' do
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

      it 'does nothing' do
        subject
      end
    end
  end

  context 'RecordNotFound' do
    subject { JSON.parse(response.body)['errors'].first }

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
    it 'makes a call to sentry when there is cause' do
      allow_any_instance_of(Rx::Client)
        .to receive(:connection).and_raise(Faraday::ConnectionFailed, 'some message')
      expect(Sentry).to receive(:set_extras).once.with(
        { request_uuid: nil }
      )
      expect(Sentry).to receive(:set_extras).once.with(
        {
          va_exception_errors: [{
            title: 'Service unavailable',
            detail: 'Backend Service Outage',
            code: '503',
            status: '503'
          }]
        }
      )
      # if current user is nil it means user is not signed in.
      expect(Sentry).to receive(:set_tags).once.with(
        {
          controller_name: 'anonymous',
          sign_in_method: 'not-signed-in',
          source: 'my_testing'
        }
      )
      expect(Sentry).to receive(:set_tags).once.with(
        { error: 'mhv_session' }
      )
      # since user is not signed in this shouldnt get called.
      expect(Sentry).not_to receive(:set_user)
      expect(Sentry).to receive(:capture_exception).once
      request.headers['Source-App-Name'] = 'my_testing'
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
        expect(Sentry).to receive(:set_extras).once.with(
          { request_uuid: nil }
        )
        expect(Sentry).to receive(:set_extras).once.with(
          {
            va_exception_errors: [{
              title: 'Service unavailable',
              detail: 'Backend Service Outage',
              code: '503',
              status: '503'
            }]
          }
        )
        # if authn_context is nil on current_user it means idme
        expect(Sentry).to receive(:set_tags).once.with(
          { controller_name: 'anonymous', sign_in_method: SignIn::Constants::Auth::IDME, sign_in_acct_type: nil }
        )

        expect(Sentry).to receive(:set_tags).once.with(
          { error: 'mhv_session' }
        )
        # since user IS signed in, this SHOULD get called
        expect(Sentry).to receive(:set_user).with(
          {
            id: user.uuid,
            authn_context: user.authn_context,
            loa: user.loa,
            mhv_icn: user.mhv_icn
          }
        )
        expect(Sentry).to receive(:capture_exception).once.with(
          Faraday::ConnectionFailed,
          level: 'error'
        )
        with_settings(Settings.sentry, dsn: 'T') do
          get :client_connection_failed
        end
        expect(JSON.parse(response.body)['errors'].first['title'])
          .to eq('Service unavailable')
      end
    end

    context 'Pundit::NotAuthorizedError' do
      subject { JSON.parse(response.body)['errors'].first }

      let(:keys_for_all_env) { %w[title detail code status] }

      context 'with Rails.env.test or Rails.env.development' do
        it 'renders json object with developer attributes' do
          get :not_authorized

          expect(response).to have_http_status(:forbidden)
          expect(subject.keys).to eq(keys_for_all_env)
        end

        it 'does not log info level and extra context to Sentry' do
          expect(Sentry).not_to receive(:capture_exception).with(
            Pundit::NotAuthorizedError,
            level: 'info'
          )
          expect(Sentry).not_to receive(:set_extras).with(
            va_exception_errors: [{
              title: 'Forbidden',
              detail: 'User does not have access to the requested resource',
              code: '403',
              status: '403'
            }]
          )
          expect(Sentry).to receive(:set_extras).once.with(
            request_uuid: nil
          )

          expect(Sentry).not_to receive(:capture_exception)

          with_settings(Settings.sentry, dsn: 'T') do
            get :not_authorized
          end

          expect(response).to have_http_status(:forbidden)
          expect(subject.keys).to eq(keys_for_all_env)
        end
      end

      context 'with Rails.env.production' do
        it 'renders json error with production attributes' do
          allow(Rails)
            .to(receive(:env))
            .and_return(ActiveSupport::StringInquirer.new('production'))

          get :not_authorized
          expect(response).to have_http_status(:forbidden)
          expect(subject.keys)
            .to eq(keys_for_all_env)
        end
      end
    end

    describe '#test_authentication' do
      let(:user) { build(:user, :loa3) }
      let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
      let(:header_host_value) { Settings.hostname }
      let(:header_auth_value) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

      before do
        session_object = Session.create(uuid: user.uuid, token:)
        User.create(user)

        session_object.to_hash.each { |k, v| session[k] = v }

        request.env['HTTP_HOST'] = header_host_value
        request.env['HTTP_AUTHORIZATION'] = header_auth_value
      end

      context 'with valid session and user' do
        it 'returns success' do
          get :test_authentication
          expect(response).to have_http_status(:ok)
        end

        it 'appends user uuid to payload' do
          get(:test_authentication)
          expect(controller.payload[:user_uuid]).to eq(user.uuid)
        end

        context 'with a credential that is locked' do
          let(:user) { build(:user, :loa3, :idme_lock) }

          it 'returns an unauthorized status' do
            get :test_authentication
            expect(response).to have_http_status(:unauthorized)
            expect(JSON.parse(response.body)['errors'].first)
              .to eq('title' => 'Not authorized', 'detail' => 'Not authorized', 'code' => '401', 'status' => '401')
          end
        end
      end

      context 'with valid session and no user' do
        before { user.destroy }

        it 'renders json error' do
          get :test_authentication
          expect(controller.instance_variable_get(:@session_object).uuid).to eq(user.uuid)
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first)
            .to eq('title' => 'Not authorized', 'detail' => 'Not authorized', 'code' => '401', 'status' => '401')
        end
      end

      context 'without valid session' do
        before { Session.find(token).destroy }

        it 'renders json error' do
          get :test_authentication
          expect(controller.instance_variable_get(:@session_object)).to be_nil
          expect(session).not_to be_empty
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first)
            .to eq('title' => 'Not authorized', 'detail' => 'Not authorized', 'code' => '401', 'status' => '401')
        end
      end
    end
  end

  describe '#sso_logging_info' do
    subject { get :test_logging }

    let(:user) { build(:user, :loa3, :legacy_icn) }
    let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
    let(:header_auth_value) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:request_host) { Settings.hostname }
    let(:expiration_time) { Session.find(token).ttl_in_time.iso8601(0) }
    let(:sso_cookie_content) do
      {
        'patientIcn' => '123498767V234859',
        'signIn' => {
          'serviceName' => 'idme',
          'authBroker' => 'iam',
          'clientId' => 'vaweb'
        },
        'credential_used' => 'idme',
        'credential_uuid' => user.idme_uuid,
        'user_credentials' => {
          idme: user.user_account.user_verifications.idme.count,
          logingov: user.user_account.user_verifications.logingov.count
        },
        'session_uuid' => token,
        'expirationTime' => expiration_time
      }
    end
    let(:expected_result) do
      {
        user_uuid: user.uuid,
        sso_cookie_contents: sso_cookie_content,
        request_host:
      }
    end

    before do
      allow(Rails.logger).to receive(:info)
      session_object = Session.create(uuid: user.uuid, token:)
      User.create(user)
      session_object.to_hash.each { |k, v| session[k] = v }
      sign_in_as(user, session_object.token)
    end

    context 'with origin logging' do
      context 'when controller has a name' do
        it 'adds controller class name as origin to logs within around_action' do
          expect(SemanticLogger).to receive(:named_tagged).with(origin: 'anonymous_controller').and_call_original
          expect(Rails.logger).to receive(:info).with(expected_result)
          subject
        end
      end

      context 'when controller class name is blank' do
        it 'does not call SemanticLogger.named_tagged when class name is blank' do
          allow(controller.class).to receive(:name).and_return('')
          expect(SemanticLogger).not_to receive(:named_tagged)
          expect(Rails.logger).to receive(:info).with(expected_result)
          subject
        end
      end
    end

    context 'when the current user and session object exist' do
      it 'returns the current user session token' do
        expect(Rails.logger).to receive(:info).with(expected_result)
        subject
      end
    end
  end
end
