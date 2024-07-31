# frozen_string_literal: true

require 'rx/client'
require 'rx/medications_client'

module MyHealth
  class RxController < ApplicationController
    include ActionController::Serialization
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-medications'

    protected

    def client
      @client ||= Rx::MedicationsClient.new(session: { user_id: current_user.mhv_correlation_id })
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_prescriptions, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
    end
  end
end
