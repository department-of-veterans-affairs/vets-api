# frozen_string_literal: true

module V0
  class PreferredFacilitiesController < ApplicationController
    def index
      render(
        json: current_user.account.preferred_facilities
      )
    end
  end
end
