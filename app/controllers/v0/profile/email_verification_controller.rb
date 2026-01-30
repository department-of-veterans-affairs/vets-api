# frozen_string_literal: true

# API for LOA3 users to verify email addresses. Includes status checks,
# sending verification emails, and token verification.
#
# Rate limited: 1 email per 5 minutes, max 5 per day per user.
# Requires Flipper flag: auth_exp_email_verification_enabled
#
module V0
  module Profile
    class EmailVerificationController < ApplicationController
      include EmailVerificationRateLimited
      include EmailVerificationErrorHandler

      service_tag 'profile-email-verification'

      before_action :check_feature_enabled!
      before_action :authenticate_loa3_user!

      def status
        verification_needed = verification_needed_or_render_va_profile_error
        return if performed?

        response_data = OpenStruct.new(
          id: SecureRandom.uuid,
          needs_verification: verification_needed
        )
        render json: EmailVerificationSerializer.new(
          response_data,
          status: verification_needed ? 'unverified' : 'verified'
        ).serializable_hash
      end

      def create
        verification_needed = verification_needed_or_render_va_profile_error
        return if performed?

        return render_verification_not_needed_error unless verification_needed

        handle_verification_errors('send verification email') do
          send_verification_email
          render_create_success
        end
      end

      def verify
        token = params[:token]
        return render_missing_token_error if token.blank?

        handle_verification_errors('verify email token') do
          process_email_verification(token)
        end
      end

      private

      def authenticate_loa3_user!
        unless current_user&.loa3?
          raise Common::Exceptions::Forbidden,
                detail: 'You must be logged in to access this feature'
        end
      end

      def check_feature_enabled!
        unless Flipper.enabled?(:auth_exp_email_verification_enabled)
          raise Common::Exceptions::Forbidden,
                detail: 'This feature is not currently available'
        end
      end

      def needs_verification?
        return false if current_user.email.blank?

        va_profile_email = current_user.va_profile_email
        return false if va_profile_email.blank?

        current_user.email.downcase != va_profile_email.downcase
      end

      def verification_needed_or_render_va_profile_error
        needs_verification?
      rescue => e
        log_va_profile_email_error(e)
        render_va_profile_unavailable_error
        nil
      end

      def log_va_profile_email_error(error)
        log_data = email_verification_log_data.merge(error: error.message, error_class: error.class.name)
        Rails.logger.warn('Email verification: VA Profile email lookup failed', log_data)
      end

      def render_va_profile_unavailable_error
        render json: {
          errors: [{
            title: 'VA Profile Unavailable',
            detail: 'VA Profile is temporarily unavailable. Please try again later.',
            code: 'EMAIL_VERIFICATION_VA_PROFILE_UNAVAILABLE',
            status: '503'
          }]
        }, status: :service_unavailable
      end

      def send_verification_email
        enforce_email_verification_rate_limit!

        template_type = params[:template_type]&.to_s || 'initial_verification'
        verification_service = EmailVerificationService.new(current_user)
        verification_service.initiate_verification(template_type)

        increment_email_verification_rate_limit!
        log_verification_success('verification email sent',
                                 template_type:,
                                 rate_limit_info: get_email_verification_rate_limit_info)
      end

      def process_email_verification(token)
        verification_service = EmailVerificationService.new(current_user)

        if verification_service.verify_email!(token)
          handle_successful_verification
        else
          handle_failed_verification(token)
        end
      end

      def handle_successful_verification
        reset_email_verification_rate_limit!
        log_verification_success('email token verified successfully',
                                 token_verification: 'success',
                                 verification_time: Time.current.iso8601)
        render_verify_success
      end

      def handle_failed_verification(token)
        log_data = email_verification_log_data.merge(
          token_verification: 'failed',
          token_length: token&.length,
          verification_time: Time.current.iso8601
        )

        Rails.logger.warn('Email verification: token verification failed', log_data)
        render_invalid_token_error
      end

      def render_verification_not_needed_error
        render json: {
          errors: [
            {
              title: 'Email Already Verified',
              detail: 'Your email address is already verified.',
              code: 'EMAIL_ALREADY_VERIFIED',
              status: '422'
            }
          ]
        }, status: :unprocessable_entity
      end

      def render_missing_token_error
        render json: {
          errors: [
            {
              title: 'Missing Token',
              detail: 'Verification token is required.',
              code: 'MISSING_TOKEN',
              status: '400'
            }
          ]
        }, status: :bad_request
      end

      def render_invalid_token_error
        render json: {
          errors: [
            {
              title: 'Invalid Token',
              detail: 'The verification token is invalid or has expired. Please request a new verification email.',
              code: 'INVALID_TOKEN',
              status: '422'
            }
          ]
        }, status: :unprocessable_entity
      end

      def render_create_success
        template_type = params[:template_type]&.to_s || 'initial_verification'
        response_data = OpenStruct.new(
          id: SecureRandom.uuid,
          email_sent: true,
          template_type:
        )
        render json: EmailVerificationSerializer.new(
          response_data,
          sent: true
        ).serializable_hash, status: :created
      end

      def render_verify_success
        response_data = OpenStruct.new(
          id: SecureRandom.uuid,
          verified: true,
          verified_at: Time.current
        )
        render json: EmailVerificationSerializer.new(
          response_data,
          verified: true
        ).serializable_hash
      end
    end
  end
end
