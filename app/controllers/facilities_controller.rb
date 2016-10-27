# frozen_string_literal: true
require 'facilities/client'

class FacilitiesController < ApplicationController
  skip_before_action :authenticate

  def validate_params
    raise ArgumentError unless params[:bbox].length == 4
    params[:bbox].each { |x| Float(x) }
  rescue ArgumentError
    raise Common::Exceptions::InvalidFieldValue.new('bbox', params[:bbox])
  end
end
