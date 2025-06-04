# frozen_string_literal: true

require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'medical_records/phr_mgr/client'
require 'medical_records/lighthouse_client'

module MyHealth
  class MRController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-medical-records'

    # skip_before_action :authenticate
    before_action :authenticate_bb_client

    protected

    ##
    # Renders 202 Accepted if the upstream client returns :patient_not_found, otherwise yields
    # the real resource to the block.
    #
    def with_patient_resource(resource)
      if resource == :patient_not_found
        render plain: '', status: :accepted
      else
        yield resource
      end
    end

    def render_resource(resource)
      if resource == :patient_not_found
        render plain: '', status: :accepted
      else
        render json: resource.to_json
      end
    end

    def client
      use_oh_data_path = Flipper.enabled?(:mhv_accelerated_delivery_enabled, @current_user) &&
                         params[:use_oh_data_path].to_i == 1
      if @client.nil?
        @client ||= if use_oh_data_path
                      MedicalRecords::LighthouseClient.new(current_user.icn)
                    else
                      MedicalRecords::Client.new(session: { user_id: current_user.mhv_correlation_id,
                                                            icn: current_user.icn })
                    end
      end
      @client
    end

    def phrmgr_client
      @phrmgr_client ||= PHRMgr::Client.new(current_user.icn)
    end

    def bb_client
      @bb_client ||= BBInternal::Client.new(session: { user_id: current_user.mhv_correlation_id,
                                                       icn: current_user.icn })
    end

    def authenticate_bb_client
      bb_client.authenticate
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_medical_records, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to medical records'
    end
  end
end
