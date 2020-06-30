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
      form_686.submit(user, payload)
    end

    private

    def form_686
      @form_686 ||= BGS::Form686c.new(current_user)
    end
  end
end