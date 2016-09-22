# frozen_string_literal: true
require_dependency 'sm/client'

class SMController < ApplicationController
  include ActionController::Serialization

  skip_before_action :authenticate
  before_action :authenticate_client

  DEFAULT_PER_PAGE = 10
  MAXIMUM_PER_PAGE = 100

  protected

  def client
    @client ||= SM::Client.new(session: { user_id: ENV['MHV_SM_USER_ID'] })
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end

  def pagination_params
    {
      page: (params[:page].try(:to_i) || 1),
      per_page: [(params[:per_page].try(:to_i) || DEFAULT_PER_PAGE), MAXIMUM_PER_PAGE].min
    }
  end
end
