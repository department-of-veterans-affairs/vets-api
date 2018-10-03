require 'services/time_of_need_service'

class TimeOfNeedController < ApplicationController
  skip_before_action(:authenticate)
  before_action(:tag_rainbows)

  protected

  def client
    @client = ::TimeOfNeed::TimeOfNeedService.new
  end
end
