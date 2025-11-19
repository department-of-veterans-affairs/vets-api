# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::V1::PrescriptionsController, type: :controller do
  let(:user) { build(:user, :mhv, mhv_account_type: 'Premium') }
  let(:prescription1) { double('Prescription', prescription_id: 1, is_refillable: true, disp_status: 'Active') }
  let(:prescription2) { double('Prescription', prescription_id: 2, is_refillable: false, disp_status: 'Active', refill_remaining: 0) }
  let(:prescription3) { double('Prescription', prescription_id: 3, is_refillable: false, disp_status: 'Expired') }
  let(:recently_requested) { [prescription1] }
  let(:filtered_prescriptions) { [prescription1, prescription2] }
  let(:all_prescriptions) { [prescription1, prescription2, prescription3] }

  let(:collection_resource) do
    Vets::Collection.new(
      all_prescriptions,
      metadata: { total: 3 }
    )
  end

  before do
    sign_in_as(user)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:collection_resource).and_return(collection_resource)
    allow(controller).to receive(:get_recently_requested_prescriptions).and_return(recently_requested)
    allow(controller).to receive(:filter_data_by_refill_and_renew).and_return(filtered_prescriptions)
    serializer_double = instance_double(MyHealth::V1::PrescriptionDetailsSerializer)
    allow(MyHealth::V1::PrescriptionDetailsSerializer).to receive(:new).and_return(serializer_double)
    allow(controller).to receive(:render)
  end

  describe '#list_refillable_prescriptions' do
    it 'calls collection_resource to get the prescription collection' do
      controller.list_refillable_prescriptions
      expect(controller).to have_received(:collection_resource)
    end

    it 'calls get_recently_requested_prescriptions with resource.data' do
      controller.list_refillable_prescriptions
      expect(controller).to have_received(:get_recently_requested_prescriptions).with(all_prescriptions)
    end

    it 'calls filter_data_by_refill_and_renew with resource.data' do
      controller.list_refillable_prescriptions
      expect(controller).to have_received(:filter_data_by_refill_and_renew).with(all_prescriptions)
    end

    it 'sets resource.records to the filtered prescriptions' do
      controller.list_refillable_prescriptions
      expect(collection_resource.records).to eq(filtered_prescriptions)
    end

    it 'serializes resource.records (not resource.data) - verifying the bug fix' do
      controller.list_refillable_prescriptions

      # Verify serializer was called with filtered_prescriptions (resource.records), not all_prescriptions (resource.data)
      expect(MyHealth::V1::PrescriptionDetailsSerializer).to have_received(:new).with(
        filtered_prescriptions,
        hash_including(meta: hash_including(recently_requested:))
      )
      # Verify it was NOT called with resource.data (unfiltered)
      expect(MyHealth::V1::PrescriptionDetailsSerializer).not_to have_received(:new).with(
        all_prescriptions,
        anything
      )
    end

    it 'includes recently_requested in the metadata' do
      controller.list_refillable_prescriptions

      expect(MyHealth::V1::PrescriptionDetailsSerializer).to have_received(:new).with(
        anything,
        hash_including(meta: hash_including(recently_requested:))
      )
    end

    it 'merges recently_requested with existing metadata' do
      controller.list_refillable_prescriptions

      expect(MyHealth::V1::PrescriptionDetailsSerializer).to have_received(:new).with(
        anything,
        hash_including(meta: hash_including(total: 3, recently_requested:))
      )
    end
  end
end

