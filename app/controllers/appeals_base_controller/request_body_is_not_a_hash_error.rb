# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

class AppealsBaseController < ApplicationController
  class RequestBodyIsNotAHash < Common::Exceptions::BaseError
    def errors
      Array Common::Exceptions::SerializableError.new i18n_data
    end

    def i18n_data
      I18n.t i18n_key
    end

    def i18n_key
      'decision_review.exceptions.DR_REQUEST_BODY_IS_NOT_A_HASH'
    end
  end
end
