# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BdnClone, type: :model do
  describe 'create' do
    let(:attributes) { FactoryBot.attributes_for(:vye_bdn_clone) }

    it 'creates a record' do
      expect do
        described_class.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end
end
