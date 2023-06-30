# frozen_string_literal: true

module Lighthouse
  module LettersGenerator
    class VeteranSponsorResolver
      # Returns the user's ICN if user is a Veteran, or the associated
      # Veteran's ICN if the user is a dependent.
      # In this relationship, the related Veteran is also called
      # "sponsor" or "headOfFamily"
      def self.get_icn(user)
        icn = user.icn

        if dependent? user
          sponsor = get_sponsor_for user
          raise ArgumentError, 'Unable to find sponsor for dependent user' unless sponsor

          icn = sponsor.icn
        end

        icn
      end

      private_class_method def self.dependent?(user)
        user.person_types&.include?('DEP')
      end

      private_class_method def self.get_sponsor_for(user)
        veteran_relationships = user.relationships&.select(&:veteran_status)
        return unless veteran_relationships.presence

        veteran_relationships.first
      end
    end
  end
end
