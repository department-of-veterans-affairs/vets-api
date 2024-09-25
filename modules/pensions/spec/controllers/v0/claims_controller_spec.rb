# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe Pensions::V0::ClaimsController, type: :controller do
  routes { Pensions::Engine.routes }

  let(:monitor) { double('Pensions::Monitor') }

  before do
    allow(Pensions::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil)
  end

  it_behaves_like 'a controller that deletes an InProgressForm', 'pension_claim', 'pensions_module_pension_claim',
                  '21P-527EZ'

  describe '#create' do
    let(:claim) { build(:pensions_module_pension_claim) }
    let(:param_name) { :pension_claim }
    let(:form_id) { '21P-527EZ' }
    let(:user) { create(:user) }

    it 'logs validation errors' do
      allow(Pensions::SavedClaim).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_validation_error).once
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
      allow(Pensions::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(500)
    end

    it 'returns a serialized claim' do
      claim = build(:pensions_module_pension_claim)
      allow(Pensions::SavedClaim).to receive(:find_by!).and_return(claim)

      response = get(:show, params: { id: 'pensions_module_pension_claim' })

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(response.status).to eq(200)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:pensions_module_pension_claim) }
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
