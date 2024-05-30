# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IvcChampva::MissingFormStatusJob', type: :job do
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil) }

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
      expect(StatsD).to have_received(:increment).with('ivc_champva.form_missing_status', tags: ["id: #{form.id}"])
    end
  end

  it 'logs an error if an exception occurs' do
    allow(IvcChampvaForm).to receive(:where).and_raise(StandardError.new('Something went wrong'))

    expect(Rails.logger).to receive(:error).twice

    IvcChampva::MissingFormStatusJob.new.perform
  end
end
