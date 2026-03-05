# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Poa2122ServiceHelpers
    class MismatchError < StandardError; end

    def normalize_codes(input)
      Array(input)
        .flatten
        .flat_map { |c| c.to_s.split(',') }
        .map(&:strip)
        .compact_blank
        .uniq
    end

    def organizations_for(codes)
      Veteran::Service::Organization.where(poa: codes)
    end

    def set_active_reps_mode!(org_scope, mode)
      reps_scope =
        Veteran::Service::OrganizationRepresentative
        .active
        .where(organization_poa: org_scope.select(:poa))
        .where.not(acceptance_mode: mode)

      expected = reps_scope.count

      updated = reps_scope.update_all(acceptance_mode: mode) # rubocop:disable Rails/SkipsModelValidations -- bulk update for performance

      if updated != expected
        raise MismatchError,
              "Poa2122ServiceHelpers#set_active_reps_mode! mismatch: expected #{expected} reps, updated #{updated}"
      end

      updated
    end
  end
end
