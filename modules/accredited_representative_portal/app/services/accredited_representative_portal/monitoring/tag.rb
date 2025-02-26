# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Monitoring
    module Tag
      module Status
        ALL = [
          ATTEMPT = 'status:attempt',
          SUCCESS = 'status:success'
        ].freeze
      end

      module Operation
        ALL = [
          CREATE = 'operation:create',
          UPDATE = 'operation:update',
          DELETE = 'operation:delete',
          SEARCH = 'operation:search',
          UPLOAD = 'operation:upload',
          DECISION = 'operation:decision',
          DOWNLOAD = 'operation:download',
          EMAIL_SEND = 'operation:email_send',
          NOTIFY = 'operation:notify',
          ACTION = ->(controller, action) { "operation:#{controller}_#{action}" }
        ].freeze
      end

      module Source
        ALL = [
          API = 'source:api',
          FRONTEND = 'source:frontend',
          SIDEKIQ = 'source:sidekiq'
        ].freeze
      end

      module Level
        ALL = [
          INFO = 'level:info',
          WARN = 'level:warn',
          ERROR = 'level:error',
          CRITICAL = 'level:critical'
        ].freeze
      end

      module Error
        ALL = [
          VALIDATION = 'error:validation',
          TIMEOUT = 'error:timeout',
          NETWORK = 'error:network',
          DATABASE = 'error:database',
          CACHE = 'error:cache',
          EXTERNAL_DEPENDENCY = 'error:external_dependency',
          HTTP_CLIENT = 'error:http_client',  # Covers 4xx errors
          HTTP_SERVER = 'error:http_server',  # Covers 5xx errors
          NOT_FOUND = 'error:not_found',
          NOT_ELIGIBLE = 'error:not_eligible',
          FORBIDDEN = 'error:forbidden',
          NOT_AUTHORIZED = 'error:not_authorized',
          DUPLICATE = 'error:duplicate',
          INVALID_STATE = 'error:invalid_state',
          FILE_ERROR = 'error:file_error',
          GENERIC = 'error:generic'
        ].freeze
      end
    end
  end
end
