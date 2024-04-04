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

        type = body.dig('data', 'type')
        code = body.dig('data', 'attributes', 'code')

        if code.blank?
          Rails.logger.warn("No power of attorney found: #{body}")
          render json: {}, status: :ok
        else
          render json: find_poa_by_code(type, code)
        end
      end

      private

      def lighthouse_service
        BenefitsClaims::Service.new(icn)
      end

      def icn
        @current_user&.icn
      end

      def find_poa_by_code(type, code)
        if type == 'organization'
          organization = find_organization(code)
          return serialize_organization(organization) if organization.present?
        else
          representative = find_representative(code)
          return serialize_representative(representative) if representative.present?
        end

        {}
      end

      def find_organization(code)
        Veteran::Service::Organization.find(code)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def find_representative(code)
        Veteran::Service::Representative.where('? = ANY(poa_codes)', code).order(created_at: :desc).first
      end

      def serialize_organization(organization)
        ActiveModelSerializers::SerializableResource.new(
          organization,
          serializer: RepresentationManagement::PowerOfAttorney::OrganizationSerializer
        ).as_json
      end

      def serialize_representative(representative)
        ActiveModelSerializers::SerializableResource.new(
          representative,
          serializer: RepresentationManagement::PowerOfAttorney::RepresentativeSerializer
        ).as_json
      end
    end
  end
end
