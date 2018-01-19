# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::VICApplicationsController, type: :controller do
  describe '#create' do
    it 'creates a vic submission job' do
      post(:create)
    end
  end
end
