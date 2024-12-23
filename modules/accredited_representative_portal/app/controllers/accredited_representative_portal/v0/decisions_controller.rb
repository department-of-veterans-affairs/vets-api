# frozen_string_literal: true

module AccreditedRepresentativePortal
    module V0
        class DecisionsController < ApplicationController
            before_action :set_power_of_attorney_request, only: [:show, :create]

            def create
                if @power_of_attorney_request.resolution.present?
                    render json: { error: 'Resolution already exists' }, status: :unprocessable_entity
                    return
                end
        
                creator_id = @current_user.id
        
                type = power_of_attorney_request_params[:declination_reason].present? ? PowerOfAttorneyRequestDecision::Types::DECLINATION :  PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
                decision = PowerOfAttorneyRequestDecision.new(type:, creator_id:)
        
                ActiveRecord::Base.transaction do
                    if decision.save
                        resolution = PowerOfAttorneyRequestResolution.new(
                            power_of_attorney_request: @power_of_attorney_request,
                            resolving: decision,
                            reason: power_of_attorney_request_params[:declination_reason]
                        )
        
                        if resolution.save
                            render json: decision, status: :ok
                        else
                            raise ActiveRecord::Rollback
                            render json: { error: 'Failed to create resolution' }, status: :unprocessable_entity
                        end
                    else
                        render json: { error: 'Failed to create decision' }, status: :unprocessable_entity
                    end
                end
            end
        
            def show
                resolution = @power_of_attorney_request.resolution
                if resolution.blank?
                    # should this error or just say Resolution not found and be status ok?
                    render json: { error: 'Resolution Not Found' }, status: :not_found
                    return
                end
        
                resolving_class = resolution.resolving_type.constantize
                outcome = resolving_class.find_by(id: resolution.resolving_id)
                if outcome.blank?
                    render json: { error: 'Outcome Not Found' }, status: :not_found
                    return
                end
        
                render json: outcome, status: :ok
            end
        
            private 
        
            def set_power_of_attorney_request
                @power_of_attorney_request = PowerOfAttorneyRequest.find_by(id: params[:power_of_attorney_request_id])
                render json: { error: 'Not Found' }, status: :not_found unless @power_of_attorney_request
            end
        
            def power_of_attorney_request_params
                params.require(:decision).permit(:declination_reason)
            end
        end
    end
end
