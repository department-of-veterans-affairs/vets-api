# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module Claimant
      class PowerOfAttorneyRequestsController < ApplicationController
        before_action :check_feature_toggle
        before_action do
          authorize PowerOfAttorneyRequest
        end

        def index
          relation = search_filter(policy_scope(PowerOfAttorneyRequest))

          poa_requests = relation.preload(scope_includes).limit(100)
          serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

          render json: serializer.serializable_hash, status: :ok
        rescue PowerOfAttorneyRequestSearchService::Error => e
          raise Common::Exceptions::BadRequest.new(detail: e.message, source: PowerOfAttorneyRequestSearchService)
        end

        private

        def search_filter(rel)
          PowerOfAttorneyRequestSearchService.new(
            rel, params[:first_name], params[:last_name], params[:dob], params[:ssn]
          ).call
        end

        def scope_includes
          [
            :power_of_attorney_form,
            :power_of_attorney_form_submission,
            :accredited_individual,
            :accredited_organization,
            { resolution: :resolving }
          ]
        end

        def check_feature_toggle
          unless Flipper.enabled?(:accredited_representative_portal_search, @current_user)
            message = 'The accredited_representative_portal_search feature flag is disabled ' \
                      "for the user with uuid: #{@current_user.uuid}"

            raise Common::Exceptions::Forbidden, detail: message
          end
        end
      end
    end
  end
end
