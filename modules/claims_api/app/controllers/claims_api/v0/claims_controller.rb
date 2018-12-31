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
               each_serializer: EVSSClaimListSerializer
      end

      def show
        claim = service.update_from_remote(params[:id])
        render json: claim, serializer: EVSSClaimDetailSerializer
      end

      private

      def service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def first_name
        first_name = request.headers['X-VA-First-Name']
        raise Common::Exceptions::ParameterMissing, 'X-VA-First-Name' unless first_name
        first_name
      end

      def last_name
        last_name = request.headers['X-VA-Last-Name']
        raise Common::Exceptions::ParameterMissing, 'X-VA-Last-Name' unless last_name
        last_name
      end

      def edipi
        edipi = request.headers['X-VA-EDIPI']
        raise Common::Exceptions::ParameterMissing, 'X-VA-EDIPI' unless edipi
        edipi
      end

      def birth_date
        birth_date = request.headers['X-VA-Birth-Date']
        raise Common::Exceptions::ParameterMissing, 'X-VA-Birth-Date' unless birth_date
        birth_date
      end

      def va_profile
        OpenStruct.new(
          birth_date: birth_date
        )
      end

      def verify_poa
        if request.headers['X-Consumer-Custom-ID']
          unless request.headers['X-Consumer-Custom-ID'].split(',').include?(veteran_power_of_attorney)
            raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
          end
        end
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

      def veteran_power_of_attorney
        service.veteran.power_of_attorney
        'A1Q' # TODO: need to join to Charlie's PR
      end
    end
  end
end
