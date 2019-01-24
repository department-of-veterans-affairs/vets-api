# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'

module ClaimsApi
  module V0
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        verify_poa
        claims = service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      end

      def show
        claim = service.update_from_remote(params[:id])
        render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
      end

      private

      def service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def first_name
        header(key = 'X-VA-First-Name') ? header(key) : raise_missing_header(key)
      end

      def last_name
        header(key = 'X-VA-Last-Name') ? header(key) : raise_missing_header(key)
      end

      def edipi
        header(key = 'X-VA-EDIPI') ? header(key) : raise_missing_header(key)
      end

      def birth_date
        header(key = 'X-VA-Birth-Date') ? header(key) : raise_missing_header(key)
      end

      def va_profile
        OpenStruct.new(
          birth_date: birth_date
        )
      end

      def target_veteran
        ClaimsApi::Veteran.new(
          ssn: ssn,
          loa: { current: :loa3 },
          first_name: first_name,
          last_name: last_name,
          va_profile: va_profile,
          edipi: edipi,
          last_signed_in: Time.zone.now
        )
      end

      def verify_poa
        if header(key = 'X-Consumer-Custom-ID')
          unless header(key).split(',').include?(veteran_power_of_attorney)
            raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
          end
        end
      end

      def veteran_power_of_attorney
        service.veteran.power_of_attorney.code
      end
    end
  end
end
