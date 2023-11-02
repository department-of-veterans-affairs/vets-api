# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::AddIcnUpdater, type: :job do
  it_behaves_like 'a monitored worker'

  describe '#perform' do
    let(:hlr) { create(:higher_level_review_v2) }

    it 'updates the appeal record with ICN data' do
      expect(hlr.veteran_icn).to be_blank
      described_class.new.perform(hlr.id, hlr.class.to_s)
      expect(hlr.reload.veteran_icn).to be_present
    end

    xit 'does not update ICN if flipper is disabled' do
      Flipper.disable(:decision_review_icn_updater_enabled)
      # ...
    end

    xit 'it logs error & does not update INC if PII has been removed from the record' do
      hlr.update(auth_headers: nil, form_data: nil)
      # ...
    end
  end
end
