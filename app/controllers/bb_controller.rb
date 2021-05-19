# frozen_string_literal: true

require 'bb/client'

class BBController < ApplicationController
  include ActionController::Serialization
  include MHVControllerConcerns

  protected

  def client
    @client ||= BB::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end

  def authorize
    raise_access_denied unless current_user.authorize(:mhv_health_records, :access?)
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to health records'
  end
end
