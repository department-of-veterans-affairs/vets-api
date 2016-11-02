# frozen_string_literal: true
require 'rx/client'

class RxController < ApplicationController
  include ActionController::Serialization
  include MHVControllerConcerns

  protected

  def client
    @client ||= Rx::Client.new(session: { user_id: current_user.mhv_correlation_id })
  end
end
