class RoadrunnersController < ApplicationController
  def index
    @roadrunner = Roadrunner.new
    @count = params[:count] ? params[:count].to_i : 0
  end
end
