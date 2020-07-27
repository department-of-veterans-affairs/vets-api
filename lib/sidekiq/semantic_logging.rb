# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/middleware/server/logging'

class Sidekiq::SemanticLogging < Sidekiq::Middleware::Server::Logging
  def call(worker, item, queue)
    logger_tags =  {
      class: item['class'],
      jid: item['jid'],
      request_id: item['request_id'],
      remote_ip: item['remote_ip'],
      user_agent: item['user_agent']
    }

    logger.tagged(**logger_tags) do
      super
    end
  end
end
