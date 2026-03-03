# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecisionPolicy < ApplicationPolicy
    def create?
      poa_request = if @record.respond_to?(:power_of_attorney_request)
                      @record.power_of_attorney_request
                    else
                      @record
                    end

      PowerOfAttorneyRequestPolicy.new(@user, poa_request).create_decision?
    end
  end
end
