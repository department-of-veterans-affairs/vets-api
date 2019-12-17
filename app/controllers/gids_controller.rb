# frozen_string_literal: true

require 'gids_redis/GIDS'

class GIDSController < ApplicationController
  skip_before_action :authenticate

  private

  def service
    GIDS.new
  end

  def scrubbed_params
    params.except(:action, :controller, :format)
  end
end
