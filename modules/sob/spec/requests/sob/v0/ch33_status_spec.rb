# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SOB::V0::Ch33Status', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'GET sob/v0/ch33_status' do
    context 'when claimant exists'
  end
end
