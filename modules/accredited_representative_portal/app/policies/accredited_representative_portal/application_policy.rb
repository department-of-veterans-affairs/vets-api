# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      raise Pundit::NotAuthorizedError, 'must be logged in' unless user

      @user = user
      @record = record
    end

    def index?
      override_warning
      false
    end

    def show?
      override_warning
      false
    end

    def create?
      override_warning
      false
    end

    def new?
      create?
    end

    def update?
      override_warning
      false
    end

    def edit?
      update?
    end

    def destroy?
      override_warning
      false
    end

    private

    def override_warning
      Rails.logger.warn(
        "#{self.class} is using the default ##{caller_locations(1, 1)[0].label} implementation. \
 Consider overriding it."
      )
    end

    class Scope
      def initialize(user, scope)
        raise Pundit::NotAuthorizedError, 'must be logged in' unless user

        @user = user
        @scope = scope
      end

      def resolve
        raise NoMethodError, "You must define #resolve in #{self.class}"
      end

      private

      attr_reader :user, :scope
    end
  end
end
