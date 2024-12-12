# frozen_string_literal: true

#
# Pagination allows Vets::Model models to set pagination info
# for that model class.
#
# class User
#   include Vets::Model
#
#   attr_accessor :name, :age
#
#   set_pagination per_page: 21, max_per_page: 41
#
#   ...
# end
#
# User.per_page
# => 21
#
# User.max_per_page
# => 41
#

module Vets
  module Model
    module Pagination
      DEFAULT_PER_PAGE = 10
      DEFAULT_MAX_PER_PAGE = 100

      def self.included(base)
        base.extend ClassMethods
        base.private_class_method :set_pagination
      end

      module ClassMethods
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        def set_pagination(per_page:, max_per_page:)
          @per_page = per_page
          @max_per_page = max_per_page
        end

        # Provide default values if set_pagination has not been called
        def per_page
          @per_page || DEFAULT_PER_PAGE
        end

        def max_per_page
          @max_per_page || DEFAULT_MAX_PER_PAGE
        end
        # rubocop:enable ThreadSafety/ClassInstanceVariable
      end
    end
  end
end
