# frozen_string_literal: true
require_dependency 'rx/client'

class RxController < ApplicationController
  include ActionController::Serialization

  skip_before_action :authenticate
  before_action :authenticate_client

  protected

  def client
    @client ||= Rx::Client.new(session: { user_id: ENV['MHV_USER_ID'] })
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
