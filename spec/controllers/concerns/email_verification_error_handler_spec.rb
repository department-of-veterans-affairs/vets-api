# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailVerificationErrorHandler, type: :concern do
  let(:controller_class) do
    @controller_class ||= Class.new(ApplicationController) do
      include EmailVerificationErrorHandler
      attr_accessor :current_user, :response

      def needs_verification?
        true
      end

      def get_email_verification_rate_limit_info
        {
          period_count: 1,
          daily_count: 2,
          max_per_period: 1,
          max_daily: 5,
          time_until_next_email: 240
        }
      end

      def build_verification_rate_limit_message
        'Verification email limit reached. Wait 5 minutes to try again.'
      end
    end
  end

  let(:controller) { controller_class.new }
  let(:user) { build(:user, :loa3, uuid: 'test-uuid-123') }
  let(:response_mock) { OpenStruct.new(headers: {}) }

  before do
    allow(controller).to receive(:render)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    controller.current_user = user
    controller.response = response_mock
  end

  describe '#handle_verification_errors' do
    context 'when no errors occur' do
      it 'executes the block normally' do
        result = nil
        controller.handle_verification_errors('send verification email') do
          result = 'success'
        end
        expect(result).to eq('success')
      end
    end

    context 'when BackendServiceException occurs' do
      before do
        controller.handle_verification_errors('send verification email') do
          raise Common::Exceptions::BackendServiceException.new('EMAIL_SERVICE_DOWN', source: 'EmailService')
        end
      end

      it 'logs the service error with email verification context' do
        expect(Rails.logger).to have_received(:error).with(
          'Email verification service error: send verification email',
          hash_including(
            user_uuid: 'test-uuid-123',
            verification_needed: true,
            error: 'BackendServiceException: {:source=>"EmailService", :code=>"VA900"}',
            error_class: 'Common::Exceptions::BackendServiceException'
          )
        )
      end

      it 'renders email service unavailable error response' do
        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Service Unavailable',
                detail: 'The email verification service is temporarily unavailable. Please try again later.',
                code: 'EMAIL_VERIFICATION_SERVICE_UNAVAILABLE',
                status: '503'
              }
            ]
          },
          status: :service_unavailable
        )
      end
    end

    context 'when TooManyRequests error occurs' do
      before do
        controller.handle_verification_errors('send verification email') do
          raise Common::Exceptions::TooManyRequests
        end
      end

      it 'logs the rate limit error with email verification context' do
        expect(Rails.logger).to have_received(:warn).with(
          'Email verification rate limit exceeded: send verification email',
          hash_including(
            user_uuid: 'test-uuid-123',
            verification_needed: true,
            error: 'Too Many Requests',
            error_class: 'Common::Exceptions::TooManyRequests',
            rate_limit_info: {
              period_count: 1,
              daily_count: 2,
              max_per_period: 1,
              max_daily: 5,
              time_until_next_email: 240
            }
          )
        )
      end

      it 'renders verification rate limit error response' do
        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Rate Limit Exceeded',
                detail: 'Verification email limit reached. Wait 5 minutes to try again.',
                code: 'EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED',
                status: '429',
                meta: {
                  retry_after_seconds: 300
                }
              }
            ]
          },
          status: :too_many_requests
        )
      end

      it 'sets Retry-After header' do
        expect(response_mock.headers['Retry-After']).to eq('300')
      end
    end

    context 'when generic error occurs' do
      before do
        controller.handle_verification_errors('send verification email') do
          raise StandardError, 'Email service connection failed'
        end
      end

      it 'logs the unexpected error with email verification context' do
        expect(Rails.logger).to have_received(:error).with(
          'Email verification unexpected error: send verification email',
          hash_including(
            user_uuid: 'test-uuid-123',
            verification_needed: true,
            error: 'Email service connection failed',
            error_class: 'StandardError'
          )
        )
      end

      it 'renders verification internal error response' do
        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Error',
                detail: 'An unexpected error occurred during email verification. Please try again later.',
                code: 'EMAIL_VERIFICATION_INTERNAL_ERROR',
                status: '500'
              }
            ]
          },
          status: :internal_server_error
        )
      end
    end
  end

  describe '#log_verification_success' do
    it 'logs successful email verification operations with context' do
      controller.log_verification_success('verification email sent', template_type: 'initial_verification',
                                                                     rate_limit_info: { period_count: 1 })

      expect(Rails.logger).to have_received(:info).with(
        'Email verification: verification email sent',
        hash_including(
          user_uuid: 'test-uuid-123',
          verification_needed: true,
          template_type: 'initial_verification',
          rate_limit_info: { period_count: 1 }
        )
      )
    end
  end

  describe '#email_verification_log_data' do
    context 'when current_user is present' do
      it 'includes user_uuid and verification_needed in log data' do
        log_data = controller.send(:email_verification_log_data)
        expect(log_data).to include(
          user_uuid: 'test-uuid-123',
          verification_needed: true
        )
      end
    end

    context 'when current_user is nil' do
      before do
        controller.current_user = nil
      end

      it 'returns empty hash when no current_user' do
        log_data = controller.send(:email_verification_log_data)
        expect(log_data).to eq({})
      end
    end
  end

  describe 'error response methods' do
    describe '#render_email_service_unavailable_error' do
      it 'renders correct email service unavailable response' do
        controller.send(:render_email_service_unavailable_error)

        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Service Unavailable',
                detail: 'The email verification service is temporarily unavailable. Please try again later.',
                code: 'EMAIL_VERIFICATION_SERVICE_UNAVAILABLE',
                status: '503'
              }
            ]
          },
          status: :service_unavailable
        )
      end
    end

    describe '#render_verification_rate_limit_error' do
      it 'renders correct rate limit error response with default retry_after' do
        controller.send(:render_verification_rate_limit_error)

        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Rate Limit Exceeded',
                detail: 'Verification email limit reached. Wait 5 minutes to try again.',
                code: 'EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED',
                status: '429',
                meta: {
                  retry_after_seconds: 300
                }
              }
            ]
          },
          status: :too_many_requests
        )
      end

      it 'sets default Retry-After header' do
        controller.send(:render_verification_rate_limit_error)
        expect(response_mock.headers['Retry-After']).to eq('300')
      end

      context 'when Retry-After header is already set' do
        it 'preserves existing Retry-After value and uses it in meta' do
          response_mock.headers['Retry-After'] = '600'
          controller.send(:render_verification_rate_limit_error)

          expect(controller).to have_received(:render) do |args|
            expect(args[:json][:errors][0][:meta][:retry_after_seconds]).to eq(600)
          end

          expect(response_mock.headers['Retry-After']).to eq('600')
        end
      end
    end

    describe '#render_verification_internal_error' do
      it 'renders correct internal error response' do
        controller.send(:render_verification_internal_error)

        expect(controller).to have_received(:render).with(
          json: {
            errors: [
              {
                title: 'Email Verification Error',
                detail: 'An unexpected error occurred during email verification. Please try again later.',
                code: 'EMAIL_VERIFICATION_INTERNAL_ERROR',
                status: '500'
              }
            ]
          },
          status: :internal_server_error
        )
      end
    end
  end

  describe 'rate limit info error handling' do
    it 'handles rate limit info retrieval errors gracefully' do
      allow(controller).to receive(:get_email_verification_rate_limit_info).and_raise(StandardError,
                                                                                      'Redis connection error')

      controller.handle_verification_errors('send verification email') do
        raise Common::Exceptions::TooManyRequests
      end

      expect(Rails.logger).to have_received(:warn).with(
        'Email verification rate limit exceeded: send verification email',
        hash_including(
          user_uuid: 'test-uuid-123',
          rate_limit_info_error: 'Redis connection error'
        )
      )
    end
  end

  describe 'integration with email verification controller' do
    it 'works seamlessly with email verification operations' do
      allow(controller).to receive(:needs_verification?).and_return(false)

      result = nil
      controller.handle_verification_errors('send verification email') do
        controller.log_verification_success('verification email sent', template_type: 'initial_verification')
        result = { email_sent: true, template_type: 'initial_verification' }
      end

      expect(Rails.logger).to have_received(:info).with(
        'Email verification: verification email sent',
        hash_including(
          user_uuid: 'test-uuid-123',
          verification_needed: false,
          template_type: 'initial_verification'
        )
      )

      expect(result).to eq({ email_sent: true, template_type: 'initial_verification' })
      allow(controller).to receive(:needs_verification?).and_return(false)

      controller.handle_verification_errors('send verification email') do
        raise Common::Exceptions::BackendServiceException, 'Email service unavailable'
      end

      expect(Rails.logger).to have_received(:error).with(
        'Email verification service error: send verification email',
        hash_including(
          user_uuid: 'test-uuid-123',
          verification_needed: false,
          error: 'BackendServiceException: {:code=>"VA900"}'
        )
      )

      expect(controller).to have_received(:render).with(
        json: {
          errors: [
            {
              title: 'Email Verification Service Unavailable',
              detail: 'The email verification service is temporarily unavailable. Please try again later.',
              code: 'EMAIL_VERIFICATION_SERVICE_UNAVAILABLE',
              status: '503'
            }
          ]
        },
        status: :service_unavailable
      )
    end
  end
end
