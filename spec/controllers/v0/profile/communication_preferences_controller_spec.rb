# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::CommunicationPreferencesController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    it 'returns the right data' do
      get(:index)
      expect(response.status).to eq(200)
    end
  end
end
