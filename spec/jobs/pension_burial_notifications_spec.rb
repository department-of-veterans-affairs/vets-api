# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurialNotifications do
  subject do
    PensionBurialNotifications.new
  end

  before do
    @no_status = create(:pension_claim, status: nil)
    @status = create(:burial_claim, status: 'in process')
  end

  describe '#perform' do
    it 'should update the statuses of saved claims' do
      subject.perform
    end
  end
end
