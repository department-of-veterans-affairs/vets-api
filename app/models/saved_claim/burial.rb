# frozen_string_literal: true

##
# Burial 21P-530EZ Active::Record
# proxy for backwards compatibility
#
# @see modules/burials/app/models/burials/saved_claim.rb
#
class SavedClaim::Burial < SavedClaim
  # form_id, form_type
  FORM = Burials::FORM_ID
end
