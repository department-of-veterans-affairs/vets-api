# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeUsersController, type: :routing do
  describe 'routing' do
    it 'routes to #show' do
      expect(get: '/accredited_representative_portal/v0/user').to route_to(
        'accredited_representative_portal/v0/representative_users#show', format: :json
      )
    end
  end
end
