# frozen_string_literal: true
module Workflow
  module Web
    def self.add_to_sidekiq
      Sidekiq::Web.register(self)
      Sidekiq::Web.tabs['workflows'] = 'workflows'
      Sidekiq::Web.locales << ::File.expand_path('lib/workflow/locales')
    end

    def self.registered(app)
      app.get '/workflows' do
        @retries = Sidekiq::RetrySet.new.find_all do |job|
          job.queue == Runner::QUEUE
        end

        erb(::File.read('app/views/sidekiq/workflows.erb'))
      end
    end
  end
end
