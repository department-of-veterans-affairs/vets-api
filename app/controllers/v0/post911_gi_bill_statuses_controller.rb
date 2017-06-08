# frozen_string_literal: true
module V0
  class Post911GIBillStatusesController < ApplicationController
    def show
      # TODO: fetch for realz
      post911_gibs = FactoryGirl.build(:post911_gi_bill_status)
      render json: post911_gibs
    end
  end
end
