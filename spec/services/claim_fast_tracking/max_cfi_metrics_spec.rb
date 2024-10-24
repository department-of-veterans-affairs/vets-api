# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimFastTracking::MaxCfiMetrics do
  let(:metrics) { described_class.new(form, params) }
  let(:form) { create(:in_progress_526_form, metadata: form_metadata) }
  let(:form_metadata) { {} }
  let(:new_form_data) { {} }
  let(:params) { { form_data: new_form_data } }

  describe '#create_or_load_metadata' do
    subject { metrics.create_or_load_metadata }

    context 'when there is no metadata' do
      let(:form_metadata) { {} }

      it 'creates new Max CFI metadata' do
        expect(subject).to eq({ 'initLogged' => false, 'cfiLogged' => false })
      end
    end

    context 'when there is older boolean metadata' do
      let(:form_metadata) { { 'cfiMetric' => true } }

      it 'returns a metadata object in the newer hash schema' do
        expect(subject).to eq({ 'initLogged' => true, 'cfiLogged' => true })
      end
    end

    context 'when there is existing hash metadata' do
      let(:form_metadata) do
        { 'cfiMetric' => { 'initLogged' => true, 'cfiLogged' => false } }
      end

      it 'returns existing hash metadata as-is' do
        expect(subject).to eq(form_metadata['cfiMetric'])
      end
    end
  end

  describe '#log_form_update' do
    subject { metrics.log_form_update }

    context 'when starting a form 526' do
      before { expect(metrics).to receive(:log_init_metric).once }

      it 'initializes metadata, reports the init metric, and saves metadata back to params' do
        subject
        expect(params[:metadata]['cfiMetric']).to eq({ 'initLogged' => true, 'cfiLogged' => false })
      end
    end

    context 'when an error is raised' do
      before do
        allow(Rails.logger).to receive(:error)
        expect(metrics).to receive(:log_init_metric).once.and_raise(StandardError)
        expect(metrics).to receive(:log_exception_to_sentry)
      end

      it 'reports the error to Rails log and Sentry, and returns successfully' do
        subject
        expect(Rails.logger).to have_received(:error)
      end
    end
  end

  describe '#claiming_increase?' do
    subject { metrics.claiming_increase? }

    context 'when updated params indicate a CFI view' do
      let(:new_form_data) do
        { 'view:claim_type' => { 'view:claiming_increase' => true } }
      end

      it 'returns truthy' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#max_rated_disabilities_diagnostic_codes' do
    subject { metrics.max_rated_disabilities_diagnostic_codes }

    context 'when some but not all rated disabilities are at maximum percentage' do
      let(:new_form_data) do
        { 'rated_disabilities' => [
          { 'name' => 'Hypertension',
            'diagnostic_code' => 7101,
            'maximum_rating_percentage' => 30,
            'rating_percentage' => 10 },
          { 'name' => 'Tinnitus',
            'diagnostic_code' => 6260,
            'maximum_rating_percentage' => 10,
            'rating_percentage' => 10 }
        ] }
      end

      it 'returns diagnostic codes for only maximum rated disabilities' do
        expect(subject).to eq([6260])
      end
    end

    context 'when all rated disabilities are at maximum percentage' do
      let(:new_form_data) do
        { 'rated_disabilities' => [
          { 'name' => 'Hypertension',
            'diagnostic_code' => 7101,
            'maximum_rating_percentage' => 30,
            'rating_percentage' => 30 },
          { 'name' => 'Tinnitus',
            'diagnostic_code' => 6260,
            'maximum_rating_percentage' => 10,
            'rating_percentage' => 10 }
        ] }
      end

      it 'returns diagnostic codes for maximum rated disabilities' do
        expect(subject).to eq([7101, 6260])
      end
    end
  end
end
