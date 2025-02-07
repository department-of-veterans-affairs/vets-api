# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class LacsController < GIDS::LCPEController
        def index
          lacs = service.get_licenses_and_certs_v1(scrubbed_params)
          set_etag(lacs.version) if versioning_required?
          render json: lacs
        end

        def show
          render json: service.get_license_and_cert_details_v1(scrubbed_params)
        rescue LCPERedis::ClientCacheStaleError
          render json: { error: "Version invalid" }, status: :conflict
        end

        private

        def versioning_required?
          scrubbed_params.except(:version, :id).blank?
        end
      end
    end
  end
end
