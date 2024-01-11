# frozen_string_literal: true

module BenefitsClaims
  class SponsorResolver
    def self.dependent?(user)
      user.person_types&.include?('DEP')
      true
    end

    # Returns the Veteran sponsor's ICN if user is a dependent, or nil
    # if the user is not a depdendent
    # In this relationship, the related Veteran is also called
    # "sponsor" or "headOfFamily"
    def self.sponsor_icn(user)
      return nil unless dependent?(user)

      sponsor = get_sponsor_for(user)
      sponsor.icn
    end

    private_class_method def self.get_sponsor_for(user)
      veteran_relationships = user.relationships&.select(&:veteran_status)
      return unless veteran_relationships.presence

      veteran_relationships.first
    end
  end
end
