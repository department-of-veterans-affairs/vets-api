# frozen_string_literal: true

module BenefitsClaims
  class UserICNResolver
    # Returns the Veteran sponsor's ICN if user is a dependent, or nil
    # if the user is not a depdendent
    # In this relationship, the related Veteran is also called
    # "sponsor" or "headOfFamily"
    def self.resolve_icn(user)
      if dependent?(user)
        sponsor = get_sponsor_for(user)
        return sponsor.icn
      end

      user.icn
    end

    def self.dependent?(user)
      user.person_types&.include?('DEP')
      true
    end

    private_class_method def self.get_sponsor_for(user)
      veteran_relationships = user.relationships&.select(&:veteran_status)
      return unless veteran_relationships.presence

      veteran_relationships.first
    end
  end
end
