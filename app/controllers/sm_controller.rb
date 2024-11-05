# frozen_string_literal: true

require 'sm/client'

class SMController < ApplicationController
  include MHVControllerConcerns
  include JsonApiPaginationLinks
  service_tag 'legacy-mhv'

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end

  def authorize
    raise_access_denied unless current_user.authorize(:legacy_mhv_messaging, :access?)
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
  end

  def use_cache?
    params[:useCache]&.downcase == 'true'
  end
end
