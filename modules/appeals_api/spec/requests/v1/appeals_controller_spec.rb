# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::AppealsController, type: :request do
  it_behaves_like 'appeals status endpoints',
                  appeals_endpoint: '/services/appeals/v1/appeals',
                  oauth_scopes: described_class::OAUTH_SCOPES[:GET]
end
