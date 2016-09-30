# frozen_string_literal: true
require_dependency 'facilities/client'

class FacilitiesController < ApplicationController
  skip_before_action :authenticate
end
