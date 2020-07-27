# frozen_string_literal: true

class FacilitiesController < ApplicationController
  skip_before_action :authenticate

  def validate_params
    if params[:bbox]
      raise ArgumentError unless params[:bbox]&.length == 4

      params[:bbox].each { |x| Float(x) }
    end
  rescue ArgumentError
    raise Common::Exceptions::InvalidFieldValue.new('bbox', params[:bbox])
  end
end
