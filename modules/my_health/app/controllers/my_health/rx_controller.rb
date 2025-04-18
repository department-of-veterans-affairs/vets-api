# frozen_string_literal: true

require 'rx/client'
require 'rx/medications_client'

module MyHealth
  class RxController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-medications'

    protected

    def client
      Rails.logger.info('Client is being set for VA.gov')
      @client ||= if Flipper.enabled?(:mhv_medications_client_test)
                    Rx::Client.new(
                      session: { user_id: current_user.mhv_correlation_id },
                      upstream_request: request,
                      app_token: Rx::Client.configuration.app_token_va_gov
                    )
                  else
                    Rx::MedicationsClient.new(
                      session: { user_id: current_user.mhv_correlation_id },
                      upstream_request: request
                    )
                  end
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_prescriptions, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
    end
  end
end
