# frozen_string_literal: true

# EmailVerificationController
#
# This controller implements the email verification API for LOA3 authenticated users.
# It handles the complete email verification workflow including status checks,
# sending verification emails, and verifying tokens.
#
# ## Endpoints:
# - GET  /v0/profile/email_verification/status  - Check if verification is needed
# - POST /v0/profile/email_verification         - Send verification email
# - GET  /v0/profile/email_verification/verify  - Verify token from email link
#
# ## Rate Limiting:
# Email sending (POST /v0/profile/email_verification) is rate limited:
# - 1 email per 5-minute period per user
# - Maximum 5 emails per 24-hour period per user
# - Rate limits are stored in Redis with automatic expiration
# - Rate limit violations return HTTP 429 with retry-after information
# - Successful verification resets rate limits
#
# ## Authentication:
# All endpoints require LOA3 authentication
#
module V0
  module Profile
    class EmailVerificationController < ApplicationController
      include EmailVerificationRateLimited
      include EmailVerificationErrorHandler

      service_tag 'profile-email-verification'

      before_action :authenticate_loa3_user!

      # GET /v0/profile/email_verification/status
      # Check if email verification is needed
      def status
        response_data = OpenStruct.new(
          id: SecureRandom.uuid,
          needs_verification: needs_verification?
        )
        render json: EmailVerificationSerializer.new(
          response_data,
          status: true
        )
      end

      # POST /v0/profile/email_verification
      # Initiate email verification process (send verification email)
      def create
        return render_verification_not_needed_error unless needs_verification?

        handle_verification_errors('send verification email') do
          send_verification_email
          render_create_success
        end
      end

      # GET /v0/profile/email_verification/verify
      # Verify email using token from verification email link
      def verify
        token = params[:token]
        return render_missing_token_error unless token.present?

        handle_verification_errors('verify email token') do
          process_email_verification(token)
        end
      end

      private

      # Check if email verification is needed
      # User's identity email differs from their VA Profile email
      def needs_verification?
        return false unless current_user.email.present? && current_user.va_profile_email.present?

        current_user.email.downcase != current_user.va_profile_email.downcase
      end

      # Enforce LOA3 authentication
      def authenticate_loa3_user!
        unless current_user&.loa3?
          raise Common::Exceptions::Forbidden,
                detail: 'You must be logged in to access this feature'
        end
      end

      # Send verification email and handle rate limiting
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

      # Process email verification with the provided token
      def process_email_verification(token)
        verification_service = EmailVerificationService.new(current_user)

        if verification_service.verify_email!(token)
          handle_successful_verification
        else
          handle_failed_verification(token)
        end
      end

      # Handle successful email verification
      def handle_successful_verification
        reset_email_verification_rate_limit!
        log_verification_success('email token verified successfully',
                                 token_verification: 'success',
                                 verification_time: Time.current.iso8601)
        render_verify_success
      end

      # Handle failed email verification
      def handle_failed_verification(token)
        # Use the new error handler for consistent logging, but don't include the actual token for security
        log_data = email_verification_log_data.merge(
          token_verification: 'failed',
          token_length: token&.length,
          verification_time: Time.current.iso8601
        )

        Rails.logger.warn('Email verification: token verification failed', log_data)
        render_invalid_token_error
      end

      # Render error when verification is not needed
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

      # Render error when token is missing
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

      # Render error when token is invalid
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

      # Render success response for verification email sent
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
        ), status: :created
      end

      # Render success response for email verification
      def render_verify_success
        response_data = OpenStruct.new(
          id: SecureRandom.uuid,
          verified: true,
          verified_at: Time.current
        )
        render json: EmailVerificationSerializer.new(
          response_data,
          verified: true
        )
      end
    end
  end
end
