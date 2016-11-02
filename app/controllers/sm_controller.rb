# frozen_string_literal: true
require 'sm/client'

class SMController < ApplicationController
  include ActionController::Serialization

  before_action :authorize_sm
  before_action :authenticate_client

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end

  def authorize_sm
    current_user&.can_access_mhv? || raise_access_denied
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
