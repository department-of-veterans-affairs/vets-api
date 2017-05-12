# frozen_string_literal: true
module Workflow
  module Web
    def self.registered(app)
      app.get '/workflows' do
        @retries = Sidekiq::RetrySet.new.find_all do |job|
          job.queue == Runner::QUEUE
        end

        erb(File.read('app/views/sidekiq/workflows.erb'))
      end
    end
  end
end
