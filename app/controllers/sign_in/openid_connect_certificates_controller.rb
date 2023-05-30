# frozen_string_literal: true

module SignIn
  class OpenidConnectCertificatesController < SignIn::ApplicationController
    skip_before_action :authenticate

    def index
      render json: SignIn::OpenidConnectCertificatesPresenter.new.perform
    end
  end
end
