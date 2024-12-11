# frozen_string_literal: true


=begin

Sortable allows Vets::Model models to specify a default sort attribute and direction
for use with `#sort`.

class User
  include Vets::Model

  attr_accessor :name, :age

  default_sort_by name: :asc

  ...
end

[user1, user3, user4, user2].sort
#=> [user1, user2, user3, user4]

=end

module Vets
  module Model
    module Sortable
      include Comparable

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        # sets the default sorting criteria
        # required for use with Array#sort
        def default_sort_by(sort_criteria)
          if sort_criteria.size != 1
            raise ArgumentError, "Only one attribute and direction can be provided in default_sort_by"
          end

          attribute, direction = sort_criteria.first
          unless [:asc, :desc].include?(direction)
            raise ArgumentError, "Direction must be either :asc or :desc"
          end

          @default_sort_criteria = sort_criteria
        end

        def default_sort_criteria
          @default_sort_criteria ||= {}
        end
      end

      def <=>(other)
        return 0 unless self.class.default_sort_criteria.any?

        attribute = self.class.default_sort_criteria.keys.first
        direction = self.class.default_sort_criteria[attribute]  || :asc

        # Validate if the attribute value is comparable
        unless comparable?(attribute)
          raise ArgumentError, "Attribute '#{attribute}' is not comparable."
        end

        comparison_result = public_send(attribute) <=> other.public_send(attribute)
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
