# frozen_string_literal: true

require 'medical_records/client'
require 'medical_records/phr_mgr/client'

module MyHealth
  class MrController < ApplicationController
    include ActionController::Serialization
    include MyHealth::MHVControllerConcerns
    service_tag 'mhv-medical-records'

    # skip_before_action :authenticate

    protected

    def client
      @client ||= MedicalRecords::Client.new(session: { user_id: current_user.mhv_correlation_id,
                                                        icn: current_user.icn })
    end

    def phrmgr_client
      @phrmgr_client ||= PHRMgr::Client.new(current_user.icn)
    end

    def authorize
      # raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    # def raise_access_denied
    #   # raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    # end
  end
end
