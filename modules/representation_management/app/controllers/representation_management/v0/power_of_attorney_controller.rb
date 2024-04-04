# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module RepresentationManagement
  module V0
    class PowerOfAttorneyController < ApplicationController
      service_tag 'representation-management'

      def index
        begin
          body = lighthouse_service.get_power_of_attorney
        rescue BenefitsClaims::ServiceException => e
          Rails.logger.error("Error fetching power of attorney: #{e.message}")
          return render json: { error: 'Unable to fetch power of attorney information' }, status: :service_unavailable
        end

        poa = get_poa(body)

        if poa.blank?
          Rails.logger.warn("No power of attorney found: #{body}")
          render json: {}, status: :ok
        else
          render json: poa, serializer: serializer_class(type(body)), status: :ok
        end
      end

      private

      def lighthouse_service
        BenefitsClaims::Service.new(icn)
      end

      def icn
        @current_user&.icn
      end

      def get_poa(body)
        poa_type = type(body)
        poa_code = code(body)

        if poa_type == 'organization'
          return find_organization(poa_code)
        else
          representative = find_representative(poa_code)
          return representative if representative.present?
        end

        {}
      end

      def type(body)
        @type ||= body.dig('data', 'type')
      end

      def code(body)
        body.dig('data', 'attributes', 'code')
      end

      def find_organization(poa_code)
        Veteran::Service::Organization.find(poa_code)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def find_representative(poa_code)
        Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).order(created_at: :desc).first
      end

      def serializer_class(type)
        if type == 'organization'
          RepresentationManagement::PowerOfAttorney::OrganizationSerializer
        else
          RepresentationManagement::PowerOfAttorney::RepresentativeSerializer
        end
      end
    end
  end
end
