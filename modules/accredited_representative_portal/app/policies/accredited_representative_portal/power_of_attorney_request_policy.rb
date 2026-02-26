# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      return authorize unless individual_accept_enabled?

      authorize_individual_access_for_record
    end

    def create_decision?
      return authorize unless individual_accept_enabled?

      authorize_individual_access_for_record
    end

    private

    def authorize
      @user.power_of_attorney_holders.any?(
        &:accepts_digital_power_of_attorney_requests?
      )
    end

    def individual_accept_enabled?
      Flipper.enabled?(:accredited_representative_portal_individual_accept, @user)
    end

    def authorize_individual_access_for_record
      poa_code = @record.power_of_attorney_holder_poa_code

      return false unless user_can_access_org?(poa_code)

      org_rep = Veteran::Service::OrganizationRepresentative
                .active
                .where(organization_poa: poa_code, representative_id: @user.registration_numbers)
                .order(created_at: :desc)
                .first

      return false if org_rep.nil?

      case org_rep.acceptance_mode
      when 'any_request'
        true
      when 'self_only'
        request_reg_num = @record.accredited_individual&.representative_id
        request_reg_num.present? && @user.registration_numbers.include?(request_reg_num)
      when 'no_acceptance'
        false
      end || false
    end

    def user_can_access_org?(poa_code)
      @user.power_of_attorney_holders.any? do |holder|
        holder.poa_code == poa_code && holder.accepts_digital_power_of_attorney_requests?
      end
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.unredacted.for_power_of_attorney_holders(
          @user.power_of_attorney_holders.select(
            &:accepts_digital_power_of_attorney_requests?
          )
        )
      end
    end
  end
end
