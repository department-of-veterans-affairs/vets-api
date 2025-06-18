# frozen_string_literal: true

require 'sm/client'

module MyHealth
  class SMController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-messaging'

    protected

    skip_before_action :authenticate

    def client
      #  @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id, user_uuid: current_user.uuid })
      # @client ||= SM::Client.new(session: { user_id: 9792157 }) # STAGING USER
      # @client ||= SM::Client.new(session: { user_id: 1_571_704 }) # DEV USER
      # @client ||= SM::Client.new(session: { user_id: 7366505 }) # SYST MHV smautotest4
      # @client ||= SM::Client.new(session: { user_id: 10055239 }) # SYST vets.gov.user+41@gmail.co
      # @client ||= SM::Client.new(session: { user_id: 21579884 }) # OH messages user
      # @client ||= SM::Client.new(session: { user_id: 10202439 }) # SYSB MHVTP, ROBERT FORD
      # @client ||= SM::Client.new(session: { user_id: 9_712_240 }) # MHVMARK mhvmark.test@id.me
      # @client ||= SM::Client.new(session: { user_id: 22336066 }) # Theo
      # @client ||= SM::Client.new(session: { user_id: 24_488_346 }) # Gustav OH vagovohtestpatient+gustav@gmail.com
      @client ||= SM::Client.new(session: { user_id: 9_950_125 }) # INTB OH user
    end

    def authorize
      # raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    end

    def use_cache?
      params[:useCache]&.downcase == 'true'
    end
  end
end
