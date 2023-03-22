# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class BaseController < ::ApplicationController
    before_action :authorize

    protected

    def authorize
      raise_access_denied unless current_user.authorize(:vaos, :access?)
      raise_access_denied_no_icn if current_user.icn.blank?
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to online scheduling'
    end

    def raise_access_denied_no_icn
      raise Common::Exceptions::Forbidden, detail: 'No patient ICN found'
    end
  end
end
