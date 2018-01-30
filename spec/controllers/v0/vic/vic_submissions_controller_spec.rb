# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::VICSubmissionsController, type: :controller do
  describe '#create' do
    it 'creates a vic submission' do
      post(:create, vic_submission: { form: build(:vic_submission).form })
      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(VIC::VICSubmission.last.guid)
    end
  end
end
