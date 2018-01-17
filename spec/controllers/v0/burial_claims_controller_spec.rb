# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BurialClaimsController, type: :controller do
  describe '#create' do
    it 'should delete the saved form' do
      expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('21P-530').once

      post(:create, burial_claim: { form: build(:burial_claim).form })
    end
  end
end
