# frozen_string_literal: true
require_dependency 'rx/client'

class RxController < ApplicationController
  include ActionController::Serialization

  before_action :authorize_rx
  before_action :authenticate_client

  protected

  def client
    @client ||= Rx::Client.new(session: { user_id: mhv_correlation_id })
  end

  def authorize_rx
    mhv_correlation_id || raise(Common::Exceptions::Unauthorized)
  end

  def mhv_correlation_id
    current_user.mhv_correlation_id
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
