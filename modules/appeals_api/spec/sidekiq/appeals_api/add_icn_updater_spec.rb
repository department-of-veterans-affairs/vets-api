# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::AddIcnUpdater, type: :job do
  it_behaves_like 'a monitored worker'

  describe '#perform' do
    let(:auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200996_headers.json' }
    let(:hlr) do
      # veteran_icn _should_ be set via model hook on creation, but it may be blank for older records:
      hlr = create(:higher_level_review_v2)
      hlr.veteran_icn = nil
      hlr.save
      hlr
    end

    it 'updates the appeal record with ICN data' do
      expect(hlr.veteran_icn).to be_blank
      described_class.new.perform(hlr.id, hlr.class.to_s)
      expect(hlr.reload.veteran_icn).to be_present
    end

    it 'does not update ICN if flipper is disabled', skip: 'TODO' do
      Flipper.disable(:decision_review_icn_updater_enabled) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      # ...
    end

    it 'logs error & does not update INC if PII has been removed from the record', skip: 'TODO' do
      hlr.update(auth_headers: nil, form_data: nil)
      # ...
    end
  end
end
