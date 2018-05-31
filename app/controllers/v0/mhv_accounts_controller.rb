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
      if mhv_account.creatable?
        mhv_accounts_service.create
        @partially_complete = true
      end
      mhv_accounts_service.upgrade if mhv_account.upgradable?
      render_for_create
    rescue StandardError
      raise unless @partially_complete
      render_for_create(status: :multi_status)
    end

    protected

    def authorize
      raise_access_denied unless mhv_account.creatable? || mhv_account.upgradable?
    end

    private

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You are not eligible for creating/upgrading an MHV account'
    end

    def mhv_account
      current_user.mhv_account
    end

    def mhv_accounts_service
      @mhv_accounts_service ||= MhvAccountsService.new(mhv_account)
    end

    def render_for_create(status: :accepted)
      render json: mhv_account,
             serializer: MhvAccountSerializer,
             status: status
    end
  end
end
