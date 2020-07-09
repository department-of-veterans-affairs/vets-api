# frozen_string_literal: true

module BGS
  class SubmitForm686cJob
    include Sidekiq::Worker
    #  should we do retries? If so, how many?
    #   ex.
    #   sidekiq_options(retry: 10)

    # class SubmitForm86cError < Common::Exceptions::BackendServiceException; end

    # Performs async submission to BGS for 686c form

    # perform method from example: app/workers/central_mail/submit_form4142_job.rb
    # has a 'submission id' and 'tracking'. What's that?
    def perform(user, payload)
      BGS::Form686c.new(user).submit(payload)
    end
  end
end
