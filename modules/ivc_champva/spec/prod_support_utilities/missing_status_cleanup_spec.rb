# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::ProdSupportUtilities::MissingStatusCleanup do
  let!(:one_week_ago) { 1.week.ago.utc }
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }

  before do
    # Save the original form creation times so we can restore them later
    @original_creation_times = forms.map(&:created_at)
    @original_uuids = forms.map(&:form_uuid)
    @original_statuses = forms.map(&:pega_status)
  end

  after do
    # Restore original dummy form created_at/form_uuid props in case we've adjusted them
    forms.each_with_index do |form, index|
      form.update(created_at: @original_creation_times[index])
      form.update(form_uuid: @original_uuids[index])
      form.update(pega_status: @original_statuses[index])
    end
  end

  describe 'batch_records' do
    subject = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new

    it 'returns an object containing forms grouped by form_uuid' do
      forms[0].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')
      forms[1].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')

      batches = subject.batch_records(forms)

      # We should group by the two unique form_uuids that are present
      expect(batches.count == forms.count - 1).to be true
      expect(batches['78444a0b-3ac8-454d-a28d-8d63cddd0d3b'].count).to eq(2)
    end

    it 'produces the same number of batches as there are forms if none share UUIDs' do
      batches = subject.batch_records(forms)
      expect(batches.count == forms.count).to be true
    end
  end

  describe 'manually_process_batch' do
    subject = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new

    it 'sets statuses to "Manually Processed" on provided batch' do
      batches = subject.batch_records(forms)
      _uuid, batch = batches.first

      statuses_before = batch.map(&:pega_status).uniq
      expect(statuses_before).to eq([nil])

      subject.manually_process_batch(batch)

      statuses_after = batch.map(&:pega_status).uniq
      expect(statuses_after).to eq(['Manually Processed'])
    end
  end
end
