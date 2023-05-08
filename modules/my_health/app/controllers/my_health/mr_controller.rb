# frozen_string_literal: true

require 'medical_records/client'

module MyHealth
  class MrController < ApplicationController
    include ActionController::Serialization
    # include MyHealth::MHVControllerConcerns

    skip_before_action :authenticate

    # protected

    def client
      @client ||= MedicalRecords::Client.new
    end

    # def authorize
    #   # raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    # end

    # def raise_access_denied
    #   # raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    # end

    # def use_cache?
    #   params[:useCache]&.downcase == 'true'
    # end
  end
end
