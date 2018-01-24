# frozen_string_literal: true

require 'mhv_ac/account_creation_error'

module V0
  class MhvAccountsController < ApplicationController
    include ActionController::Serialization
    include MHVControllerConcerns

    skip_before_action :authorize, only: [:show]
    skip_before_action :authenticate_client

    def show
      render json: mhv_account,
             serializer: MhvAccountSerializer
    end

    def create
      raise MHVAC::AccountCreationError if mhv_account.accessible?
      register_mhv_account unless mhv_account.previously_registered?
      upgrade_mhv_account
      head :accepted
    end

    protected

    def authorized?
      mhv_account.eligible?
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to MHV services'
    end

    private

    def register_mhv_account
      mhv_accounts_service.create
    end

    def upgrade_mhv_account
      mhv_accounts_service.upgrade
    end

    def mhv_account
      current_user.mhv_account
    end

    def mhv_accounts_service
      @mhv_accounts_service ||= MhvAccountsService.new(current_user)
    end
  end
end
