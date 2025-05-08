# frozen_string_literal: true

require 'mhv/aal/client'

module MyHealth
  ##
  # Module to support AAL logging. By design, the methods here do not block execution of the request
  # if there is an error. They simply log the error instead.
  #
  module AALClientConcerns
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_aal_client
    end

    protected

    ##
    # Convenience method to create an AAL entry. It injects a unique identifier for the VA.gov session.
    #
    def create_aal(attributes, once_per_session: false)
      aal_client.create_aal(attributes, once_per_session, current_user.last_signed_in)
    rescue => e
      Rails.logger.error "Failed to create AAL entry. #{e.message}", e.backtrace
    end

    def aal_client
      @aal_client ||= build_aal_client
    rescue => e
      Rails.logger.error "Failed to build AAL client. #{e.message}", e.backtrace
    end

    ##
    # Pull the product from the request. Alternatively, override this in your controller and hard
    # code the value. Value should be one of [:mr, :rx, :sm]
    #
    def product
      params[:product]&.to_sym
    end

    private

    def authenticate_aal_client
      aal_client.authenticate
    rescue => e
      Rails.logger.error "Failed to authenticate AAL client. #{e.message}", e.backtrace
    end

    def build_aal_client
      effective_product = product
      raise(Common::Exceptions::ParameterMissing, 'product') if effective_product.blank?

      # Pick the right subclass based on the product.
      client_class = case effective_product
                     when :mr then AAL::MRClient
                     when :rx then AAL::RXClient
                     when :sm then AAL::SMClient
                     else
                       raise Common::Exceptions::BadRequest,
                             detail: "Unknown product: #{effective_product}"
                     end

      client_class.new(session: aal_client_session)
    end

    def aal_client_session
      { user_id: current_user&.mhv_correlation_id }
    end
  end
end
