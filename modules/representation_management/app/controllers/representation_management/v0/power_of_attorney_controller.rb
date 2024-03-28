# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneyController < ApplicationController
      service_tag 'representation-management'

      def index
        poa_code = RepresentationManagement::PowerOfAttorney::Service.new(@current_user)
                                                                     .get.dig(:data, :attributes, :code)
        render json: { poa: poa_code.blank? ? {} : find_poa_by_code(poa_code) }
      end

      private

      def find_poa_by_code(code)
        organization = find_organization(code)
        return serialize_organization(organization) if organization.present?

        representative = find_representative(code)
        representative.present? ? serialize_representative(representative) : {}
      end

      def find_organization(code)
        Veteran::Service::Organization.find(code)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def find_representative(code)
        representatives = Veteran::Service::Representative.where('? = ANY(poa_codes)', code)
        representatives.empty? ? nil : representatives.first
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
