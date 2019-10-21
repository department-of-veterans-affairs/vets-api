# frozen_string_literal: true

require_dependency 'vaos/va_mobile_service'

module VAOS
  class ApplicationController < ::ApplicationController
    before_action :authorize
    
    protected

    def authorize
      raise_access_denied unless current_user.authorize(:vaos, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to online scheduling'
    end

    def va_mobile_service
      VAMobileService.new
    end
  end
end
