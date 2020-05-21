# frozen_string_literal: true

module V0
  class MHVAccountsController < ApplicationController
    CREATE_ERROR = 'You are not eligible for creating an MHV account'
    UPGRADE_ERROR = 'You are not eligible for upgrading an MHV account'
    include ActionController::Serialization

    def show
      render_account
    end

    def create
      if mhv_account.creatable?
        mhv_accounts_service.create
        render_account(status: :created)
      else
        raise Common::Exceptions::Forbidden, detail: CREATE_ERROR
      end
    end

    def upgrade
      if mhv_account.upgradable?
        mhv_accounts_service.upgrade
        render_account(status: :accepted)
      else
        raise Common::Exceptions::Forbidden, detail: UPGRADE_ERROR
      end
    end

    private

    def mhv_account
      current_user.mhv_account
    end

    def mhv_accounts_service
      @mhv_accounts_service ||= MHVAccountsService.new(mhv_account, current_user)
    end

    def render_account(status: :ok)
      render json: mhv_account,
             serializer: MHVAccountSerializer,
             status: status
    end
  end
end
