# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedOrganizationsController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      INVALID_ORG_PREFIX = 'zzz-'

      def index
        model_class = use_accredited_model? ? AccreditedOrganization : Veteran::Service::Organization
        organizations = model_class
                        .where('LOWER(name) NOT LIKE ?', "#{INVALID_ORG_PREFIX}%")
                        .order(name: :asc)

        json_response = organizations.map do |org|
          unless org.is_a?(AccreditedOrganization)
            org = RepresentationManagement::AccreditedOrganizationAdapter.new(org)
          end

          RepresentationManagement::AccreditedOrganizations::OrganizationSerializer.new(org).serializable_hash
        end

        render json: json_response
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_enabled)
      end

      def use_accredited_model?
        Flipper.enabled?(:find_a_representative_use_accredited_models)
      end
    end
  end
end
