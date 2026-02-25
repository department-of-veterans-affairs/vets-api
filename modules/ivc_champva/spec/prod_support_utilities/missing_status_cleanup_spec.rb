# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::ProdSupportUtilities::MissingStatusCleanup do
  subject { described_class.new }

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

  describe '#get_missing_statuses' do
    it 'returns batches of records with nil pega_status' do
      cleanup = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(cleanup)

      allow(cleanup).to receive_messages(
        get_missing_statuses: forms.each_with_object({}) do |form, hash|
          hash[form.form_uuid] = IvcChampvaForm.where(form_uuid: form.form_uuid)
        end,
        display_batch: nil
      )

      result = subject.get_missing_statuses

      expect(result.keys.count).to eq(3)
      result.each_value do |batch|
        expect(batch.count).to eq(1)
        expect(batch.first.pega_status).to be_nil
      end
    end

    it 'filters out records created in the last minute when ignore_last_minute is true' do
      recent_form = create(:ivc_champva_form, pega_status: nil, created_at: Time.now.utc)

      result = subject.get_missing_statuses(silent: true, ignore_last_minute: true)

      # Should only see the older forms, not the recent one
      expect(result.keys.count).to eq(3)
      expect(result.keys).not_to include(recent_form.form_uuid)

      recent_form.destroy
    end

    it 'filters out records created in the last 2 hours when ignore_recent is true' do
      recent_form = create(:ivc_champva_form, pega_status: nil, created_at: 2.hours.ago.utc)
      most_recent_form = create(:ivc_champva_form, pega_status: nil, created_at: 2.hours.ago.utc + 2.minutes)
      result = subject.get_missing_statuses(silent: true, ignore_recent: true)

      expect(result.keys.count).to eq(4)
      expect(result.keys).not_to include(most_recent_form.form_uuid)

      most_recent_form.destroy
      recent_form.destroy
    end

    it 'calls display_batch when silent is false' do
      display_batch_called = 0
      original_method = described_class.instance_method(:display_batch)

      # Temporarily redefine the method
      described_class.define_method(:display_batch) do |batch|
        display_batch_called += 1
        original_method.bind(self).call(batch)
      end

      subject.get_missing_statuses(silent: false)

      # Verify the behavior
      expect(display_batch_called).to eq(forms.count)

      # Restore the original method
      described_class.define_method(:display_batch, original_method)
    end

    it 'does not call display_batch when silent is true' do
      # Create a spy to verify the behavior
      display_batch_called = false
      original_method = described_class.instance_method(:display_batch)

      # Temporarily redefine the method
      described_class.define_method(:display_batch) do |batch|
        display_batch_called = true
        original_method.bind(self).call(batch)
      end

      subject.get_missing_statuses(silent: true)

      # Verify the behavior
      expect(display_batch_called).to be false

      # Restore the original method
      described_class.define_method(:display_batch, original_method)
    end
  end

  describe '#get_batches_for_email' do
    let(:email) { 'test@example.com' }

    before do
      forms.each { |form| form.update(email:) }
    end

    it 'returns batches of records with matching email' do
      result = subject.get_batches_for_email(email_addr: email, silent: true)

      expect(result.keys.count).to eq(3)
      result.each_value do |batch|
        expect(batch.count).to eq(1)
        expect(batch.first.email).to eq(email)
      end
    end

    it 'calls display_batch when silent is false' do
      display_batch_called = 0
      original_method = described_class.instance_method(:display_batch)

      # Temporarily redefine the method
      described_class.define_method(:display_batch) do |batch|
        display_batch_called += 1
        original_method.bind(self).call(batch)
      end

      subject.get_batches_for_email(email_addr: email, silent: false)

      # Verify the behavior
      expect(display_batch_called).to eq(forms.count)

      # Restore the original method
      described_class.define_method(:display_batch, original_method)
    end

    it 'does not call display_batch when silent is true' do
      display_batch_called = false
      original_method = described_class.instance_method(:display_batch)

      # Temporarily redefine the method
      described_class.define_method(:display_batch) do |batch|
        display_batch_called = true
        original_method.bind(self).call(batch)
      end

      subject.get_batches_for_email(email_addr: email, silent: true)

      # Verify the behavior
      expect(display_batch_called).to be false

      # Restore the original method
      described_class.define_method(:display_batch, original_method)
    end
  end

  describe 'batch_records' do
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

  describe '#display_batch' do
    let(:batch) { IvcChampvaForm.where(form_uuid: forms.first.form_uuid) }

    it 'outputs batch information to stdout' do
      form = batch.first
      fraction = '1/1'

      expect do
        subject.display_batch(batch)
      end.to output(/#{form.first_name} #{form.last_name}.*#{fraction}.*#{form.email}/).to_stdout
      expect { subject.display_batch(batch) }.to output(/Form UUID:.*#{form.form_uuid}/).to_stdout
      expect { subject.display_batch(batch) }.to output(/Form:.*#{form.form_number}/).to_stdout
      expect { subject.display_batch(batch) }.to output(/Uploaded at:.*#{form.created_at}/).to_stdout
      expect { subject.display_batch(batch) }.to output(/S3 Status:.*#{batch.distinct.pluck(:s3_status)}/).to_stdout
    end

    it 'returns nil' do
      expect(subject.display_batch(batch)).to be_nil
    end

    it 'returns early if batch is empty' do
      empty_batch = IvcChampvaForm.where(form_uuid: 'non-existent-uuid')
      expect(subject.display_batch(empty_batch)).to be_nil
      expect { subject.display_batch(empty_batch) }.not_to output.to_stdout
    end
  end

  describe 'manually_process_batch' do
    it 'sets statuses to "Manually Processed" on provided batch' do
      batches = subject.batch_records(forms)
      _uuid, batch = batches.first

      statuses_before = batch.map(&:pega_status).uniq
      expect(statuses_before).to eq([nil])

      subject.manually_process_batch(batch)

      statuses_after = batch.map(&:pega_status).uniq
      expect(statuses_after).to eq(['Manually Processed'])
    end

    it 'skips records that already have a pega_status' do
      form = forms.first
      form.update(pega_status: 'Processed')

      batch = IvcChampvaForm.where(form_uuid: form.form_uuid)
      expect(Rails.logger).not_to receive(:info).with(/Setting.*#{form.file_name}.*to 'Manually Processed'/)

      subject.manually_process_batch(batch)

      # Status should remain unchanged
      expect(form.reload.pega_status).to eq('Processed')
    end

    it 'logs information about each processed record' do
      batches = subject.batch_records(forms)
      _uuid, batch = batches.first

      form = batch.first
      expect(Rails.logger).to receive(:info).with(/Setting.*#{form.file_name}.*to 'Manually Processed'/)

      subject.manually_process_batch(batch)
    end
  end
end
