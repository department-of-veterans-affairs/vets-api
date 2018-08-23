# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern

  def create_user_account
    return unless @current_user.uuid

    Account.find_or_create_by!(idme_uuid: @current_user.uuid) do |account|
      account.edipi = @current_user&.edipi
      account.icn   = @current_user&.icn
    end
  end
end
