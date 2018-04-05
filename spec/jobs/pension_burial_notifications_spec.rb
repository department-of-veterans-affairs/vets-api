# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurialNotifications do
  subject do
    PensionBurialNotifications.new
  end

  before do
    @old_claim = create(:pension_claim, status: nil, created_at: '2017-01-01'.to_date)
    @no_status_claim = create(:pension_claim, status: nil)
    @in_process_claim = create(:burial_claim, status: 'in process')
    @error_claim = create(:burial_claim, status: 'pdf error')
    @success_claim = create(:burial_claim, status: 'success')
  end

  describe '#perform' do
    let(:mock_statuses) do
      [
        {
          'uuid' => @no_status_claim.guid,
          'status' => 'In Process'
        },
        {
          'uuid' => @in_process_claim.guid,
          'status' => 'Success'
        }
      ]
    end

    it 'should update the statuses of saved claims' do
      expect_any_instance_of(PensionBurialNotifications).to receive(:get_status).with(
        [@no_status_claim.guid, @in_process_claim.guid]
      ).and_return(mock_statuses)

      subject.perform

      expect(@old_claim.reload.status).to be(nil)
      expect(@error_claim.reload.status).to eq('pdf error')
      expect(@success_claim.reload.status).to eq('success')
      expect(@no_status_claim.reload.status).to eq('in process')
      expect(@in_process_claim.reload.status).to eq('success')
    end
  end
end
