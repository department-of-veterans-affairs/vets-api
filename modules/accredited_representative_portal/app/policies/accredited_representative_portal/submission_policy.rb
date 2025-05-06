# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmissionPolicy < ApplicationPolicy
    def index?
      authorize
    end

    private

    def authorize
      @user.user_account.active_power_of_attorney_holders.size.positive?
    end
  end
end
