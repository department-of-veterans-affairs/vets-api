# frozen_string_literal: true

######## Why does this patch exist? ########
#
# Console1984 blocks all `instance_variable_get` and `instance_variable_set` to prevent
# adding new methods to classes, changing class-state or accessing/overridden instance variables via reflection.
# This is meant to prevent manipulating certain Console1984 classes during a console session.
#
# The `datadog` gem wants to access the DB connection configuration hash from the current connection.
#
# The result of this incompatibility is an error when accessing Rails console in live environments
#
# You can't invoke instance_variable_get on #<ActiveRecord::ConnectionAdapters::PostgreSQLAdapter>
#
# This will likely be the case for many versions in the future, so a patch is required. Instead of patching
# the `datadog` gem, it would less risky to patch the `console1984` gem and allow
#
############################################

module Console1984
  module Freezeable
    module ClassMethods
      private

      def prevent_sensitive_method(method_name)
        define_method(method_name) do |*arguments|
          if instance_of?(ActiveRecord::ConnectionAdapters::PostGISAdapter)
            super(*arguments)
          else
            raise Console1984::Errors::ForbiddenCommandAttempted, "You can't invoke #{method_name} on #{self}"
          end
        end
      end
    end
  end
end
