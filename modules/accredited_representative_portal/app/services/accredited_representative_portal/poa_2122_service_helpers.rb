# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Poa2122ServiceHelpers
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

      updated = 0
      reps_scope.find_each do |org_rep|
        org_rep.update!(acceptance_mode: mode)
        updated += 1
      end

      updated
    end
  end
end
