# frozen_string_literal: true
module V0
  class LettersController < ApplicationController
    def index
      response = EVSS::Letters::Letter.find_by_user(@current_user)
      render json: response.as_json
    end

    # :nocov:
    def show
      head :ok
    end
    # :nocov:
  end
end
