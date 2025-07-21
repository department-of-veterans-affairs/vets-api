# frozen_string_literal: true

require 'sm/client'

module MyHealth
  class SMController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-messaging'

    protected

    def client
      @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id, user_uuid: current_user.uuid })
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    end

    def use_cache?
      params[:useCache]&.downcase == 'true'
    end

    ##
    # Determines the value for requires_oh_messages parameter based on the
    # mhv_secure_messaging_cerner_pilot flipper flag.
    #
    # @return [String] '1' if the flipper is enabled for the current user, '0' otherwise
    def requires_oh_messages
      return '1' if Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user)

      '0'
    end
  end
end
