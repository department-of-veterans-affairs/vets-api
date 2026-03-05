# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    VALID_ACCEPTANCE_MODES = %w[any_request self_only no_acceptance].freeze

    def index?
      legacy_authorize
    end

    def show?
      authorize_with_individual_accept
    end

    def create_decision?
      authorize_with_individual_accept
    end

    private

    def legacy_authorize
      @user.power_of_attorney_holders.any?(&:accepts_digital_power_of_attorney_requests?)
    end

    def record_org_participates?
      return false unless @record.respond_to?(:power_of_attorney_holder_poa_code)

      poa_code = @record.power_of_attorney_holder_poa_code
      @user.power_of_attorney_holders.any? do |holder|
        holder.poa_code == poa_code && holder.accepts_digital_power_of_attorney_requests?
      end
    end

    def authorize_with_individual_accept
      return legacy_authorize unless individual_accept_enabled?
      return legacy_authorize unless @record.respond_to?(:power_of_attorney_holder_poa_code)

      return false unless record_org_participates?

      mode = acceptance_mode_for_record_org
      return false if mode.blank?
      return false unless VALID_ACCEPTANCE_MODES.include?(mode)

      return false if mode == 'no_acceptance'
      return true if mode == 'any_request'

      self_only_allows?
    end

    def individual_accept_enabled?
      Flipper.enabled?(:accredited_representative_portal_individual_accept, @user)
    end

    def acceptance_mode_for_record_org
      poa_code = @record.power_of_attorney_holder_poa_code

      org_rep = Veteran::Service::OrganizationRepresentative
                .active
                .where(organization_poa: poa_code, representative_id: Array(@user.registration_numbers))
                .order(created_at: :desc)
                .first

      org_rep&.acceptance_mode
    end

    def self_only_allows?
      request_reg_num = @record.accredited_individual_registration_number
      return false if request_reg_num.blank?

      Array(@user.registration_numbers).include?(request_reg_num)
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        base = base_scope
        return base unless individual_accept_enabled?

        any_request_orgs, self_only_orgs = partition_orgs_by_acceptance_mode
        return base.none if any_request_orgs.empty? && self_only_orgs.empty?

        any_request_scope =
          any_request_orgs.empty? ? base.none : base.where(power_of_attorney_holder_poa_code: any_request_orgs)

        self_only_scope =
          if self_only_orgs.empty?
            base.none
          else
            base
              .where(power_of_attorney_holder_poa_code: self_only_orgs)
              .where(accredited_individual_registration_number: Array(@user.registration_numbers))
          end

        any_request_scope.or(self_only_scope)
      end

      private

      def individual_accept_enabled?
        Flipper.enabled?(:accredited_representative_portal_individual_accept, @user)
      end

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
          .where(organization_poa: allowed_poa_codes, representative_id: Array(@user.registration_numbers))
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
