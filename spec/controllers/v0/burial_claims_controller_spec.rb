# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::BurialClaimsController, type: :controller do
  it_should_behave_like 'a controller that deletes an InProgressForm', 'burial_claim', 'burial_claim', '21P-530'

  describe '#show' do
    it 'should return the submission status' do
      claim = create(:burial_claim)
      claim.central_mail_submission.update_attributes!(state: 'success')
      get(:show, id: claim.guid)

      expect(JSON.parse(response.body)['data']['attributes']['state']).to eq('success')
    end
  end
end
