# frozen_string_literal: true

require 'email_verification/jwt_generator'

class EmailVerificationService
  TOKEN_BYTES = 32 # 256 bits
  REDIS_EXPIRATION = 15.minutes.to_i

  REDIS_NAMESPACE = 'email_verification'

  def initialize(user)
    @user = user
    @redis = Redis::Namespace.new(REDIS_NAMESPACE, redis: $redis)
  end

  def initiate_verification(template_name = 'initial_verification')
    token = generate_token
    store_token_in_redis(token)

    # initial_verification, annual_verification, and email_change_verification
    template_type = template_name.to_s

    personalisation = {
      'verification_link' => generate_verification_link(token),
      'first_name' => @user.first_name,
      'email_address' => @user.email
    }
    EmailVerificationJob.perform_async(template_type, @user.email, personalisation)

    token
  rescue Redis::BaseError, Redis::CannotConnectError => e
    raise Common::Exceptions::BackendServiceException.new(
      'VA900',
      {
        detail: "Redis error during email verification: #{e.class} - #{e.message}",
        operation: 'initiate_verification',
        user_uuid: @user&.uuid,
        backtrace: e.backtrace&.take(10)
      }
    )
  end

  def verify_email!(token)
    stored_token = @redis.get(redis_key)
    if stored_token == token
      @redis.del(redis_key)
      # email = VAProfile::Models::Email.new(
      #  verification_date: Time.now.utc.iso8601
      # )
      # VAProfile::ContactInformation::V2::Service.new(@user).update_email(email)

      # Trigger background job to send success verification email
      template_type = 'verification_success'
      personalisation = {
        'verification_link' => generate_verification_link(token),
        'first_name' => @user.first_name,
        'email_address' => @user.email
      }
      EmailVerificationJob.perform_async(template_type, @user.email, personalisation)
      true
    else
      Rails.logger.warn("Email verification failed: invalid token for user #{@user.uuid}")
      false
    end
  rescue Redis::BaseError, Redis::CannotConnectError => e
    log_redis_error('Redis error during email verification', e)
    raise Common::Exceptions::BackendServiceException.new('Redis', e)
  end

  private

  def generate_verification_link(token)
    # TODO: Implement actual link once endpoints are created (controller ticket)
    "https://va.gov/email/verify?token=#{token}&uuid=#{@user.uuid}"
  end

  def generate_token
    EmailVerification::JwtGenerator.new(@user).encode_jwt
  end

  def store_token_in_redis(token)
    @redis.del(redis_key)
    @redis.set(redis_key, token)
    @redis.expire(redis_key, REDIS_EXPIRATION)
  end

  def redis_key
    @user.uuid
  end

  def log_redis_error(message, error)
    error_data = {
      error_class: error.class.name,
      error_message: error.message,
      user_uuid: @user&.uuid
    }
    Rails.logger.error(message, error_data)
  end
end
