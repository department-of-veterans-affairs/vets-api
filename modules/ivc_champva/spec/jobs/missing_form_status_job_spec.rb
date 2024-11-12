# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IvcChampva::MissingFormStatusJob', type: :job do
  let!(:one_week_ago) { 1.week.ago.utc }
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }

  before do
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(true)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)
  end

  it 'sends the count of forms to DataDog' do
    IvcChampva::MissingFormStatusJob.new.perform

    expect(StatsD).to have_received(:gauge).with('ivc_champva.forms_missing_status.count', forms.count)
  end

  it 'sends each form UUID to DataDog' do
    IvcChampva::MissingFormStatusJob.new.perform

    forms.each do |form|
      expect(StatsD).to have_received(:increment).with('ivc_champva.form_missing_status', tags: ["id:#{form.id}"])
    end
  end

  it 'logs an error if an exception occurs' do
    allow(IvcChampvaForm).to receive(:where).and_raise(StandardError.new('Something went wrong'))

    expect(Rails.logger).to receive(:error).twice

    IvcChampva::MissingFormStatusJob.new.perform
  end

  context 'Feature champva_failure_email_job_enabled=true' do
    before do
      allow(Flipper).to receive(:enabled?).with(:champva_failure_email_job_enabled, nil).and_return(true)
    end

    it 'sends count of forms missing Pega status for >= 7 days to DataDog' do
      IvcChampva::MissingFormStatusJob.new.perform
      forms.each do |form|
        expect(StatsD).to have_received(:increment)
          .with('ivc_champva.form_missing_status_email_sent', tags: ["id:#{form.id}"])
      end
    end
  end
end
