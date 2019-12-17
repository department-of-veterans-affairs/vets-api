# frozen_string_literal: true

require 'gids_redis/Gids'

class GidsController < ApplicationController
  skip_before_action :authenticate

  private

  def service
    Gids.new
  end

  def scrubbed_params
    params.except(:action, :controller, :format)
  end
end
