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
      before_action :authenticate_aal_client, unless: :_aal_public_controller?
    end

    protected

    ##
    # Convenience method to create an AAL entry. It injects a unique identifier for the VA.gov
    # session. This method will NOT raise errors, allowing requests to continue.
    #
    # Use this method in controllers where logging is a side-effect, rather than the primary
    # function.
    #
    def create_aal(attributes, once_per_session: false)
      create_aal!(attributes, once_per_session:)
    rescue => e
      Rails.logger.error "Failed to create AAL entry. #{e.message}", e.backtrace
    end

    ##
    # Convenience method to create an AAL entry. It injects a unique identifier for the VA.gov
    # session. This method WILL raise errors, blocking request execution.
    #
    def create_aal!(attributes, once_per_session: false)
      aal_client.create_aal(attributes, once_per_session, current_user&.last_signed_in)
    end

    def authenticate_aal_client
      authenticate_aal_client!
    rescue => e
      Rails.logger.error "Failed to authenticate AAL client. #{e.message}", e.backtrace
    end

    def authenticate_aal_client!
      aal_client.authenticate
    end

    ##
    # This method yields a block and automatically logs an AAL, capturing whether it succeeded
    # (status = 1) or failed (status = 0). It re-raises any errors after logging so downstream error
    # handling remains unaffected.
    #
    # @yield The block of code to execute and log.
    # @return [Object] The result of the yielded block.
    # @raise [Exception] Re-raises any exception raised within the block after logging the failure.
    #
    def handle_aal(activity_type, action, detail_value = nil, performer_type = 'Self', once_per_session: false)
      response = yield
      create_aal({ activity_type:, action:, performer_type:, detail_value:, status: 1 }, once_per_session:)
      response
    rescue => e
      create_aal({ activity_type:, action:, performer_type:, detail_value:, status: 0 }, once_per_session:)
      raise e
    end

    private

    def aal_client
      @aal_client ||= build_aal_client
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

    ##
    # Pull the product from the request. Alternatively, override this in your controller and hard
    # code the value. Value should be one of [:mr, :rx, :sm]
    #
    def product
      params[:product]&.to_sym
    end

    def _aal_public_controller?
      self.class <= MyHealth::V1::AALController
    end
  end
end
