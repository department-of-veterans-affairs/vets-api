# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < EVSSClaimDetailSerializer
    attributes :token, :status, :evss_id, :flashes

    attribute :evss_errors, if: -> {  object.status == 'errored' }

    type :claims_api_claim

    def id
      object&.id
    end

    def evss_errors
      if object.evss_response&.any?
        format_evss_errors(claim.evss_response['messages'])
      else
        'Unknown EVSS Async Error'
      end
    end

    def format_evss_errors(errors)
      errors.map do |error|
        formatted = error['key'] ? error['key'].gsub('.', '/') : error['key']
        { detail: "#{error['severity']} #{error['detail'] || error['text']}".squish, source: formatted }
      end
    end
  end
end
