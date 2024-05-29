# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

def logger_mock(str, x)
  print(str, x)
end

RSpec.describe V0::PensionClaimsController, type: :controller do
  it_behaves_like 'a controller that deletes an InProgressForm', 'pension_claim', 'pension_claim', '21P-527EZ'
  describe '#create' do
    let(:form) { build(:pension_claim) }
    let(:param_name) { :pension_claim }
    let(:form_id) { '21P-527EZ' }
    let(:user) { create(:user) }

    it('logs a success') do
      expect(Rails.logger).to receive(:info).with('21P-527EZ submission to Sidekiq begun',
                                                  hash_including(:confirmation_number, :user_uuid))
      expect(Rails.logger).to receive(:info).with('21P-527EZ submission to Sidekiq success',
                                                  hash_including(:confirmation_number, :user_uuid,
                                                                 :in_progress_form_id))
      post(:create, params: { param_name => { form: form.form } })
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(Rails.logger).to receive(:error).once
      claim = create(:pension_claim)
      guid = claim.guid
      claim.destroy
      response = get(:show, params: { id: guid })
      expect(response.status).to eq(404)
    end
  end
end
