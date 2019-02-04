# frozen_string_literal: true

class V0::BgsController < ApplicationController
  skip_before_action :authenticate

  def index
    BGS.poa_finder
  end
end
