# frozen_string_literal: true

module Common::Client
  module ServiceStatus
    extend ActiveSupport::Concern

    RESPONSE_STATUS = {
      ok: 'OK',
      not_found: 'NOT_FOUND',
      server_error: 'SERVER_ERROR',
      not_authorized: 'NOT_AUTHORIZED'
    }.freeze
  end
end
