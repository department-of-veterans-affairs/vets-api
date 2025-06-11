# frozen_string_literal: true

##
# Pension 21P-527EZ Active::Record
# proxy for backwards compatibility
#
# @see modules/pensions/app/models/pensions/saved_claim.rb
#
class SavedClaim::Pension < SavedClaim
  # form_id, form_type
  FORM = '21P-527EZ'
end
