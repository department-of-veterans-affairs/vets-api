# frozen_string_literal: true

module SignIn
  module AudienceValidator
    extend ActiveSupport::Concern

    included do
      prepend Authentication
      class_attribute :valid_audience # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    end

    class_methods do
      def validates_access_token_audience(*audience)
        return if audience.empty?

        self.valid_audience = audience.flatten.compact
      end
    end

    protected

    def authenticate
      validate_audience!
      super
    rescue Errors::InvalidAudienceError => e
      render json: { errors: e }, status: :unauthorized
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue Errors::StandardError => e
      handle_authenticate_error(e)
    end

    private

    def validate_audience!
      valid_audience = self.class.valid_audience

      return if valid_audience.blank?
      return if access_token.audience.any? { |aud| valid_audience.include?(aud) }

      Rails.logger.error('[SignIn][AudienceValidator] Invalid audience',
                         { invalid_audience: access_token.audience, valid_audience: })
      raise Errors::InvalidAudienceError.new(message: 'Invalid audience')
    end
  end
end
