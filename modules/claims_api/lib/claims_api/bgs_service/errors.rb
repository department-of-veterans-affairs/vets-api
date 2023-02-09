# frozen_string_literal: true

module ClaimsApi
  module LocalBGS
    # This error is raised when the BGS SOAP API returns a ShareException
    # fault back to us. We special-case the handling to raise this custom
    # type down in `request`, where we will kick this up if we're accessing
    # something that's above our sensitivity level.
    class ShareError < StandardError
      alias body message

      # Many BGS calls fail in off-hours because BGS has maintenance time, so it's useful to classify
      # these transient errors and ignore them in our reporting tools. These are marked transient because
      # they're self-resolving and a request can be retried (this typically happens during jobs).
      #
      # Only add new kinds of transient BGS errors when you have investigated that they are expected,
      # and they happen frequently enough to pollute the alerts channel.
      TRANSIENT_ERRORS = [
        # This occasionally happens when client/server timestamps get out of sync. Uncertain why this
        # happens or how to fix it - it only happens occasionally.
        #
        # A more detailed message is
        #   "WSSecurityException: The message has expired (WSSecurityEngine: Invalid timestamp The
        #    security semantics of the message have expired)"
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2884/
        'WssVerification Exception - Security Verification Exception',

        # Some context:
        #   "So when the call to get contentions occurred, our BGS call runs through the
        #   Tuxedo layer to get further information, but ran into the issue with BDN and failed the
        #   remainder of the call"
        #
        # BDN = Benefits Delivery Network
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2910/
        'ShareException thrown in findVeteranByPtcpntId',

        #  Similar to above, an outage of connection to BDN.
        #
        # Example:https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2926/
        'The Tuxedo service is down',

        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2888/
        'Connection timed out - connect(2) for \'bepprod.vba.va.gov\' port 443',

        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3128/
        'Connection refused - connect(2) for \'bepprod.vba.va.gov\' port 443',

        # BGS kills connection
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3129/
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3036/
        'Connection reset by peer',

        # Connection timeout
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2935/
        'execution expired',

        # Transient failure when, for example, a WSDL is unavailable. For example, the originating
        # error could be a Wasabi::Resolver::HTTPError
        #  "Error: 504 for url http://localhost:10001/BenefitClaimServiceBean/BenefitClaimWebService?WSDL"
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2928/
        'HTTP error (504): upstream request timeout',

        # Like above
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3573/
        'HTTP error (503): upstream connect error',

        # Transient failure because a VBMS service is unavailable.
        #
        # Examples:
        # :find_benefit_claim
        #   https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/2891/
        # :find_veteran_by_file_number
        #   https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3576/
        'Unable to find SOAP operation:',

        # I don't understand why this happens, but it's transient.
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3404/
        'Unable to parse SOAP message',

        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3404/
        'TUX-20306 - An unexpected error was encountered',

        # Full message may be something like
        # "An error occurred while establishing the claim: Unable to establish claim: TUX-20308 -
        # An unexpected error was encountered. Please contact the System Administrator. Error is: TUX-20308"
        #
        # https://sentry.ds.va.gov/department-of-veterans-affairs/caseflow/issues/3288/
        'System error with BGS'
      ].freeze

      attr_reader :message, :code

      def initialize(message, code = nil)
        @message = message.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        @code = code
        super(@message)
      end

      def ignorable?
        TRANSIENT_ERRORS.any? { |transient_error| message.include?(transient_error) }
      end
    end

    class PublicError < StandardError
      attr_accessor :public_message

      def initialize(message)
        @public_message = message.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        super
      end
    end
  end
end
