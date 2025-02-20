# frozen_string_literal: true

#
# Sortable allows Vets::Model models to specify a default sort attribute and direction
# for use with `#sort`.
#
# class User
#   include Vets::Model
#
#   attr_accessor :name, :age
#
#   default_sort_by name: :asc
#
#   ...
# end
#
# [user1, user3, user4, user2].sort
#=> [user1, user2, user3, user4]
#

module Vets
  module Model
    module Sortable
      include Comparable
      extend ActiveSupport::Concern

      class_methods do
        # sets the default sorting criteria
        # required for use with Array#sort
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        def default_sort_by(sort_criteria)
          if sort_criteria.size != 1
            raise ArgumentError, 'Only one attribute and direction can be provided in default_sort_by'
          end

          _, direction = sort_criteria.first
          raise ArgumentError, 'Direction must be either :asc or :desc' unless %i[asc desc].include?(direction)

          @default_sort_criteria = sort_criteria
        end

        def default_sort_criteria
          @default_sort_criteria ||= {}
        end
        # rubocop:enable ThreadSafety/ClassInstanceVariable
      end

      def <=>(other)
        return 0 unless self.class.default_sort_criteria.any?

        attribute = self.class.default_sort_criteria.keys.first
        direction = self.class.default_sort_criteria[attribute] || :asc

        # Validate if the attribute value is comparable
        raise ArgumentError, "Attribute '#{attribute}' is not comparable." unless comparable?(attribute)

        self_value = public_send(attribute)
        other_value = other.public_send(attribute)

        return  0 if !self_value && !other_value
        return  1 unless self_value
        return -1 unless other_value

        comparison_result = self_value <=> other_value
        direction == :desc ? -comparison_result : comparison_result
      end

      private

      def comparable?(attribute)
        value = public_send(attribute)
        value.is_a?(Comparable)
      end
    end
  end
end
