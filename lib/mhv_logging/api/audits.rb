# frozen_string_literal: true
module MHVLogging
  module API
    # This module defines the actions that audits can perform
    module Audits
      def auditlogin
        body = { isSuccessful: true, activityDetails: 'Signed in Vets.gov' }
        perform(:post, 'activity/auditlogin', body, token_headers)
      end

      def auditlogout
        body = { isSuccessful: true, activityDetails: 'Signed out Vets.gov' }
        perform(:post, 'activity/auditlogout', body, token_headers)
      end
    end
  end
end
