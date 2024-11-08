# frozen_string_literal: true

module V1
  module GIDS
    module Lce
      class CertificationsController < LceController
        def show
          render json: service.get_certification_details_v1(scrubbed_params)
        end
      end
    end
  end
end
