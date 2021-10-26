# frozen_string_literal: true

# NOTE: robust testing for this controller is in spec/requests/evss_claims_async_spec.rb

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EVSSClaimsAsyncController, type: :controller do
  it_behaves_like 'a controller that does not log 404 to Sentry'
end
