# frozen_string_literal: true

module V0
  class GiBillFeedbacks < ApplicationController
    skip_before_action(:authenticate)
    before_action(:tag_rainbows)

    def create
      authenticate_token
    end
  end
end
