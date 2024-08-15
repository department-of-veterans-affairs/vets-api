# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::IncomeAndAssetsClaimsController, type: :controller do
  let(:monitor) { double('IncomeAndAssets::Claims::Monitor') }
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(IncomeAndAssets::Claims::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil)
  end

  it_behaves_like 'a controller that deletes an InProgressForm', 'income_and_assets_claim', 'income_and_assets_claim',
                  '21P-0969'

  describe '#create' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:param_name) { :income_and_assets_claim }
    let(:form_id) { '21P-0969' }

    it 'logs validation errors' do
      allow(SavedClaim::IncomeAndAssets).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_error).once
      expect(claim).not_to receive(:upload_to_lighthouse)

      response = post(:create, params: { param_name => { form: claim.form } })

      expect(response.status).to eq(500)
    end

    it('returns a serialized claim') do
      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once

      response = post(:create, params: { param_name => { form: claim.form } })

      expect(JSON.parse(response.body)['data']['attributes']['form']).to eq(form_id)
      expect(response.status).to eq(200)
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(monitor).to receive(:track_show404).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(404)
    end

    it 'logs an error' do
      error = StandardError.new('Mock Error')
      allow(SavedClaim::IncomeAndAssets).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(500)
    end

    it 'returns a serialized claim' do
      claim = build(:income_and_assets_claim)
      allow(SavedClaim::IncomeAndAssets).to receive(:find_by!).and_return(claim)

      response = get(:show, params: { id: 'income_and_assets_claim' })

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(response.status).to eq(200)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns if a `blank` in_progress_form' do
      ['', [], {}, nil].each do |blank|
        expect(in_progress_form).not_to receive(:update)
        result = subject.send(:log_validation_error_to_metadata, blank, claim)
        expect(result).to eq(nil)
      end
    end

    it 'updates the in_progress_form' do
      expect(in_progress_form).to receive(:metadata).and_return(in_progress_form.metadata)
      expect(in_progress_form).to receive(:update)
      subject.send(:log_validation_error_to_metadata, in_progress_form, claim)
    end
  end

  # end RSpec.describe
end
