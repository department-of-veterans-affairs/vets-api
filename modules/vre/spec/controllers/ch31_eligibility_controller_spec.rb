# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::V0::Ch31EligibilityStatusesController, type: :controller do
  routes { VRE::Engine.routes }

  let(:user) { create(:user) }
  before { sign_in_as(user) }

  describe 'GET ch31_eligibility_status' do
  end
end
