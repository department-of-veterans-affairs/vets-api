# frozen_string_literal: true
require 'vic_helper'

module V0
  class IdCardAttributesController < ApplicationController
    def show
      vic_url = VIC::Helper.generate_url(@current_user)
      redirect_to vic_url
    end
  end
end
