# frozen_string_literal: true
require 'sm/client'

class SMController < ApplicationController
  include ActionController::Serialization
  include MHVControllerConcerns

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
  end
end
