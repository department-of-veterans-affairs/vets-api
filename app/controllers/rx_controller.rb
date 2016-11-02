# frozen_string_literal: true
require 'rx/client'

class RxController < ApplicationController
  include ActionController::Serialization

  skip_before_action :authenticate
  before_action :authorize_rx
  before_action :authenticate_client

  protected

  def client
    @client ||= Rx::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end

  def authorize_rx
    current_user&.can_access_mhv? || raise_access_denied
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
