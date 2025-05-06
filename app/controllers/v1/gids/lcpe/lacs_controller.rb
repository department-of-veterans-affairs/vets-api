# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class LacsController < GIDS::LCPEController
        def index
          lacs = service.get_licenses_and_certs_v1(scrubbed_params)
          set_headers(lacs[:version]) unless bypass_versioning?
          render json: lacs
        end

        def show
          render json: service.get_license_and_cert_details_v1(scrubbed_params)
        end
      end
    end
  end
end
