# frozen_string_literal: true

# EmailVerificationsController
#
# This controller implements the email verification API for LOA3 authenticated users.
# It handles the complete email verification workflow including status checks,
# sending verification emails, and verifying tokens.
#
# ## Endpoints:
# - GET  /v0/profile/email_verifications/status  - Check if verification is needed
# - POST /v0/profile/email_verifications         - Send verification email
# - GET  /v0/profile/email_verifications/verify  - Verify token from email link
#
# ## Rate Limiting:
# Email sending (POST /v0/profile/email_verifications) is rate limited:
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
    class EmailVerificationsController < ApplicationController
      include RateLimited

      service_tag 'profile-email-verification'

      # Configure rate limiting for email verification
      rate_limit :email_verification,
                 per_period: 1,
                 period: 5.minutes,
                 daily_limit: 5,
                 redis_namespace: 'email_verification_rate_limit'

      before_action :authenticate_user!

      # GET /v0/profile/email_verifications/status
      # Check if email verification is needed
      def status
        render json: {
          data: {
            type: 'email_verification_status',
            attributes: {
              needs_verification: needs_verification?
            }
          }
        }
      end

      # POST /v0/profile/email_verifications
      # Initiate email verification process (send verification email)
      def create
        unless needs_verification?
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
          return
        end

        # Check rate limiting (but don't increment yet)
        enforce_rate_limit!(:email_verification)

        # Send verification email
        template_type = params[:template_type]&.to_s || 'initial_verification'
        verification_service = EmailVerificationService.new(current_user)
        token = verification_service.initiate_verification(template_type)

        # Increment rate limit counter after successful sending
        increment_rate_limit!(:email_verification)

        Rails.logger.info('Email verification initiated', {
                            user_uuid: current_user.uuid,
                            template_type:,
                            rate_limit_info: get_rate_limit_info(:email_verification)
                          })

        render json: {
          data: {
            type: 'email_verification',
            attributes: {
              email_sent: true,
              template_type:
            }
          }
        }, status: :created
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error('Email verification service error', {
                             user_uuid: current_user.uuid,
                             error: e.message
                           })

        render json: {
          errors: [
            {
              title: 'Service Unavailable',
              detail: 'Email verification service is temporarily unavailable. Please try again later.',
              code: 'SERVICE_UNAVAILABLE',
              status: '503'
            }
          ]
        }, status: :service_unavailable
      rescue => e
        Rails.logger.error('Unexpected error during email verification initiation', {
                             user_uuid: current_user.uuid,
                             error: e.message,
                             backtrace: e.backtrace
                           })

        render json: {
          errors: [
            {
              title: 'Internal Server Error',
              detail: 'An unexpected error occurred. Please try again later.',
              code: 'INTERNAL_SERVER_ERROR',
              status: '500'
            }
          ]
        }, status: :internal_server_error
      end

      # GET /v0/profile/email_verifications/verify
      # Verify email using token from verification email link
      def verify
        token = params[:token]

        unless token.present?
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
          return
        end

        verification_service = EmailVerificationService.new(current_user)

        if verification_service.verify_email!(token)
          # Reset rate limiting on successful verification
          reset_rate_limit!(:email_verification)

          Rails.logger.info('Email verification successful', {
                              user_uuid: current_user.uuid
                            })

          render json: {
            data: {
              type: 'email_verification',
              attributes: {
                verified: true,
                verified_at: Time.current.iso8601
              }
            }
          }
        else
          Rails.logger.warn('Email verification failed - invalid token', {
                              user_uuid: current_user.uuid,
                              token_provided: token.present?
                            })

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
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error('Email verification service error during verification', {
                             user_uuid: current_user.uuid,
                             error: e.message
                           })

        render json: {
          errors: [
            {
              title: 'Service Unavailable',
              detail: 'Email verification service is temporarily unavailable. Please try again later.',
              code: 'SERVICE_UNAVAILABLE',
              status: '503'
            }
          ]
        }, status: :service_unavailable
      rescue => e
        Rails.logger.error('Unexpected error during email verification', {
                             user_uuid: current_user.uuid,
                             error: e.message,
                             backtrace: e.backtrace
                           })

        render json: {
          errors: [
            {
              title: 'Internal Server Error',
              detail: 'An unexpected error occurred. Please try again later.',
              code: 'INTERNAL_SERVER_ERROR',
              status: '500'
            }
          ]
        }, status: :internal_server_error
      end

      private

      # Check if email verification is needed
      # User's identity email differs from their VA Profile email
      def needs_verification?
        return false unless current_user.email.present? && current_user.va_profile_email.present?

        current_user.email.downcase != current_user.va_profile_email.downcase
      end

      # Enforce LOA3 authentication (inherited from ApplicationController)
      def authenticate_user!
        unless current_user&.loa3?
          raise Common::Exceptions::Forbidden,
                detail: 'You must be logged in to access this feature'
        end
      end
    end
  end
end
