# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EVSSClaimsController, type: :controller do
  it_should_behave_like 'skip_sentry_404'
end
