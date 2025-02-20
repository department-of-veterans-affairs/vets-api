# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::Award, type: :model do
  describe 'create' do
    let(:user_info) { create(:vye_user_info) }

    it 'creates a record' do
      expect do
        attributes = attributes_for(:vye_award)
        user_info.awards.create!(attributes)
      end.to change(Vye::Award, :count).by(1)
    end
  end
end
