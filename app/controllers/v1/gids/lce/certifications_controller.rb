# frozen_string_literal: true

module V1
  module GIDS
    module LCE
      class CertificationsController < GIDSController
        def show
          render json: service.get_certification_details_v1(scrubbed_params)
        end
      end
    end
  end
end