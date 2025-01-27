# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class LacsController < GIDS::LCPEController
        def index
          render json: service.get_licenses_and_certs_v1(scrubbed_params)
        end

        def show
          render json: service.get_license_and_cert_details_v1(scrubbed_params)
        end
      end
    end
  end
end
