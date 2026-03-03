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
      # If the policy has been instantiated with a class instead of a record,
      # fall back to the general authorization logic to avoid errors.
      return authorize unless @record.respond_to?(:power_of_attorney_holder_poa_code)

      poa_code = @record.power_of_attorney_holder_poa_code

      return false unless user_can_access_org?(poa_code)

      org_rep = Veteran::Service::OrganizationRepresentative
                .active
                .where(organization_poa: poa_code, representative_id: @user.registration_numbers)
                .order(created_at: :desc)
                .first

      return false if org_rep.nil?

      mode = org_rep.acceptance_mode

      return false unless %w[any_request self_only no_acceptance].include?(mode)

      case mode
      when 'any_request'
        true
      when 'self_only'
        request_reg_num = @record.accredited_individual_registration_number
        request_reg_num.present? && @user.registration_numbers.include?(request_reg_num)
      when 'no_acceptance'
        false
      end
    end

    def user_can_access_org?(poa_code)
      @user.power_of_attorney_holders.any? do |holder|
        holder.poa_code == poa_code && holder.accepts_digital_power_of_attorney_requests?
      end
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        base = base_scope

        return base unless Flipper.enabled?(:accredited_representative_portal_individual_accept, @user)

        any_request_orgs, self_only_orgs = partition_orgs_by_acceptance_mode

        any_request_scope =
          base.where(power_of_attorney_holder_poa_code: any_request_orgs)

        self_only_scope =
          base.where(power_of_attorney_holder_poa_code: self_only_orgs)
              .where(accredited_individual_registration_number: @user.registration_numbers)

        any_request_scope.or(self_only_scope)
      end

      private

      def base_scope
        @scope.unredacted.for_power_of_attorney_holders(
          @user.power_of_attorney_holders.select(
            &:accepts_digital_power_of_attorney_requests?
          )
        )
      end

      def allowed_poa_codes
        @user.power_of_attorney_holders
             .select(&:accepts_digital_power_of_attorney_requests?)
             .map(&:poa_code)
      end

      def latest_org_reps
        Veteran::Service::OrganizationRepresentative
          .active
          .where(organization_poa: allowed_poa_codes, representative_id: @user.registration_numbers)
          .select('DISTINCT ON (organization_poa) organization_poa, acceptance_mode')
          .order('organization_poa, created_at DESC')
      end

      def partition_orgs_by_acceptance_mode
        any_request_orgs = []
        self_only_orgs = []

        latest_org_reps.each do |org_rep|
          case org_rep.acceptance_mode
          when 'any_request'
            any_request_orgs << org_rep.organization_poa
          when 'self_only'
            self_only_orgs << org_rep.organization_poa
          end
        end

        [any_request_orgs, self_only_orgs]
      end
    end
  end
end
