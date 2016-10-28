# frozen_string_literal: true
require 'sm/client'

class SMController < ApplicationController
  include ActionController::Serialization

  skip_before_action :authenticate
  before_action :authenticate_client

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: ENV['MHV_SM_USER_ID'] })
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end
end
