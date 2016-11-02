# frozen_string_literal: true
require 'sm/client'

class SMController < ApplicationController
  include ActionController::Serialization
  include MHVControllerConcerns

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end
end
