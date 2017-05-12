# frozen_string_literal: true
module Workflow
  module Web
    def self.registered(app)
      app.get '/workflows' do
        erb File.read('app/views/sidekiq/workflows.erb')
      end
    end
  end
end
