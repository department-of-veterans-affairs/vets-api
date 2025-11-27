# frozen_string_literal: true

# Monkey patch to provide Mail::CheckDeliveryParams for compatibility with mail 2.9.0+
# This module was removed in mail 2.9.0 after being deprecated.
# The govdelivery-tms gem includes this module but doesn't actually use its methods.
# This provides an empty module for compatibility until govdelivery-tms is updated.
module Mail
  module CheckDeliveryParams
    # Empty module - the deprecated methods from mail 2.8.1 are not needed
    # by any code in this application or its dependencies
  end
end
