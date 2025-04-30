# frozen_string_literal: true

require 'mhv/aal/client'

module MyHealth
  module AALClientConcerns
    extend ActiveSupport::Concern

    included do
      before_action :authorize_aal
      before_action :authenticate_aal_client
    end

    protected

    def aal_client
      @aal_client ||= build_aal_client
    end

    def build_aal_client
      # Pull from the Controller's 'product' function first, then from 'params'
      effective_product =
        if respond_to?(:product, true) && product.present?
          product
        elsif params[:product].present?
          params[:product].to_sym
        else
          raise Common::Exceptions::ParameterMissing, 'product'
        end

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

    def authorize_aal
      if current_user.mhv_correlation_id.blank?
        raise Common::Exceptions::Forbidden,
              detail: 'You do not have access to the AAL service'
      end
    end

    def authenticate_aal_client
      aal_client.authenticate
    end
  end
end
