# frozen_string_literal: true

module V0
  class MhvAccountsController < ApplicationController
    include ActionController::Serialization

    before_action :authorize, only: :create

    def show
      render json: mhv_account,
             serializer: MhvAccountSerializer
    end

    def create
      register_mhv_account unless mhv_account.previously_registered?
      upgrade_mhv_account
      render json: mhv_account,
             serializer: MhvAccountSerializer,
             status: :accepted
    end

    protected

    def authorized?
      mhv_account.eligible?
    end

    def authorize
      raise_access_denied unless creatable_or_upgradable?
      raise_requires_terms_acceptance if current_user.mhv_account.needs_terms_acceptance?
    end

    private

    def creatable_or_upgradable?
      current_user.authorize(:mhv_account_creation, :creatable?) ||
        current_user.authorize(:mhv_account_creation, :upgradable?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to MHV services'
    end

    def raise_requires_terms_acceptance
      raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service'
    end

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
