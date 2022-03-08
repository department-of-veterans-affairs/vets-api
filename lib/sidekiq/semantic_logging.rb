# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/job_logger'

class Sidekiq::SemanticLogging < Sidekiq::JobLogger
  def call(_worker, item, queue)
    logger_tags = {
      class: item['class'],
      jid: item['jid'],
      request_id: item['request_id'],
      remote_ip: item['remote_ip'],
      user_agent: item['user_agent'],
      user_uuid: item['user_uuid'] || 'N/A',
      source: item['source']
    }

    @logger.tagged(**logger_tags) do
      super(item, queue)
    end
  end
end
