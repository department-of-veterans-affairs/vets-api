# frozen_string_literal: true

module V0
    module Ask
        class AsksController < ApplicationController
            skip_before_action :authenticate, only: :create

            def create
                render json: {"message": "200 ok"}
            end
        end
    end
end
