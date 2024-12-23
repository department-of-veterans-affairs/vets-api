# frozen_string_literal: true

module AccreditedRepresentativePortal
  class InProgressFormPolicy < ApplicationPolicy
    def update?
      authorize
    end

    def show?
      authorize
    end

    def destroy?
      authorize
    end

    class Scope
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        InProgressForm.for_user(user)
      end
    end

    private

    def authorize
      return false unless user

      true
    end
  end
end
