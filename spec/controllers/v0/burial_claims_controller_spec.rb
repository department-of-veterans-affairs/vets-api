# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BurialClaimsController, type: :controller do
  describe '#create' do
    it 'should delete the saved form' do
      expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('21P-530').once

      post(:create, burial_claim: { form: build(:burial_claim).form })
    end
  end

  describe '#show' do
    it 'should return the submission status' do
      claim = create(:burial_claim)
      claim.central_mail_submission.update_attributes!(state: 'success')
      get(:show, id: claim.guid)

      expect(JSON.parse(response.body)['data']['attributes']['state']).to eq('success')
    end
  end
end
