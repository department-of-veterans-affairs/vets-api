# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::CaregiversAssistanceClaim do
  describe '#to_pdf' do
    it 'raises a NotImplementedError' do

    end
  end

  describe '#process_attachments!' do
    it 'raises a NotImplementedError' do

    end
  end

  describe '#regional_office' do
    # This method is required by it's parent: SavedClaim.
    # Can return an actual value if we ever process the claim and have a regional_office.
    it 'returns nil' do
      expect(SavedClaim::CaregiversAssistanceClaim.new.regional_office).to be(nil)
    end
  end
end
