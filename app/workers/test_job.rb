# frozen_string_literal: true

class TestJob
  include Sidekiq::Worker

  sidekiq_options retry: 1

  FILE_NAME = '/Users/silvioluthi/projects/va/vets-api/LOG.log'

  sidekiq_retries_exhausted do |msg, _ex|
    File.open(FILE_NAME, 'a') { |f| f.write("Retries exhausted for #{msg['jid']}\n") }
  end

  def perform
    raise StandardError
  end
end
