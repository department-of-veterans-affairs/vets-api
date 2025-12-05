# frozen_string_literal: true

require 'email_verification/jwt_generator'
require 'sidekiq/attr_package'

class EmailVerificationService
  TOKEN_VALIDITY_DURATION = EmailVerification::JwtGenerator::TOKEN_VALIDITY_DURATION
  REDIS_EXPIRATION = (TOKEN_VALIDITY_DURATION + 10.minutes).to_i # revocation + cleanup + time skew buffer

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

    # Store PII in Redis via AttrPackage to avoid exposing it in Sidekiq job arguments
    cache_key = Sidekiq::AttrPackage.create(
      expires_in: REDIS_EXPIRATION,
      email: @user.email,
      first_name: @user.first_name,
      verification_link: generate_verification_link(token)
    )

    EmailVerificationJob.perform_async(template_type, cache_key)

    token
  rescue Redis::BaseError, Redis::CannotConnectError => e
    log_redis_error('Redis error during email verification initiation', e)
    raise Common::Exceptions::BackendServiceException.new(
      'VA900',
      {
        detail: "Redis error during email verification: #{e.class} - #{e.message}",
        source: 'EmailVerificationService#initiate_verification'
      }
    )
  end

  def verify_email!(token)
    stored_token = @redis.get(redis_key)
    if stored_token == token
      @redis.del(redis_key)
      send_verification_success_email
      true
    else
      log_invalid_token_attempt(token)
      false
    end
  rescue Redis::BaseError, Redis::CannotConnectError => e
    log_redis_error('Redis error during email verification', e)
    raise Common::Exceptions::BackendServiceException.new(
      'VA900',
      {
        detail: "Redis error during email verification: #{e.class} - #{e.message}",
        source: 'EmailVerificationService#verify_email!'
      }
    )
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

  def log_invalid_token_attempt(attempted_token)
    Rails.logger.warn("Email verification failed: invalid token for user #{@user.uuid}", {
                        user_uuid: @user.uuid,
                        token_provided: attempted_token.present?,
                        stored_token_exists: @redis.exists(redis_key)
                      })
  end

  def send_verification_success_email
    # TODO: Update VA Profile with verification date once integration is complete
    # email = VAProfile::Models::Email.new(verification_date: Time.now.utc.iso8601)
    # VAProfile::ContactInformation::V2::Service.new(@user).update_email(email)

    # Store PII in Redis via AttrPackage to avoid exposing it in Sidekiq job arguments
    cache_key = Sidekiq::AttrPackage.create(
      expires_in: REDIS_EXPIRATION,
      first_name: @user.first_name,
      email: @user.email
    )

    EmailVerificationJob.perform_async('verification_success', cache_key)
  end
end
