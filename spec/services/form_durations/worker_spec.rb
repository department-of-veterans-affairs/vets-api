# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormDurations::Worker do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of FormDurations::Worker' do
      expect(subject.build({})).to be_a(FormDurations::Worker)
    end
  end

  describe 'object initialization' do
    let(:worker) { subject.build(form_id: 'abc-123') }

    it 'responds to attributes' do
      %i[form_id days_till_expires config duration_instance].each do |attr|
        expect(worker.respond_to?(attr)).to be(true)
      end
    end

    it 'has a config struct' do
      expect(worker.config).to be_a(OpenStruct)
    end

    context 'when form_id in Registry' do
      let(:worker) { subject.build(form_id: 'HC-QSTNR_abc123') }

      it 'config has a CustomDuration klazz' do
        expect(worker.config.klazz).to eq(FormDurations::CustomDuration)
      end

      it 'config static is false' do
        expect(worker.config.static).to be(false)
      end
    end
  end

  describe 'object constants' do
    it 'has a REGEXP_ID_MATCHER' do
      expect(subject::REGEXP_ID_MATCHER).to eq(/^[^_]*/)
    end

    it 'has a STANDARD_DURATION_NAME' do
      expect(subject::STANDARD_DURATION_NAME).to eq('standard')
    end

    it 'has a REGISTRY' do
      registry = {
        'standard' => { klazz: FormDurations::StandardDuration, static: true },
        '21-526ez' => { klazz: FormDurations::AllClaimsDuration, static: true },
        'hc-qstnr' => { klazz: FormDurations::CustomDuration, static: false },
        '686c-674-v2' => { klazz: FormDurations::CustomDuration, static: false }
      }

      expect(subject::REGISTRY).to eq(registry)
    end
  end

  describe '#get_duration' do
    context 'when form not in Registry' do
      let(:worker) { subject.build(form_id: 'abc-123') }

      it 'config has a StandardDuration klazz' do
        expect(worker.config.klazz).to eq(FormDurations::StandardDuration)
      end

      it 'config static is true' do
        expect(worker.config.static).to be(true)
      end

      it 'has a duration of 60 days' do
        expect(worker.get_duration).to eq(60.days)
      end
    end

    context 'when All Claims Form' do
      let(:worker) { subject.build(form_id: '21-526ez') }

      it 'config has a AllClaimsDuration klazz' do
        expect(worker.config.klazz).to eq(FormDurations::AllClaimsDuration)
      end

      it 'config static is true' do
        expect(worker.config.static).to be(true)
      end

      it 'has a duration of 1 year' do
        expect(worker.get_duration).to eq(1.year)
      end
    end

    context 'when dynamic form with expiration days' do
      let(:worker) { subject.build(form_id: 'HC-QSTNR_abc123', days_till_expires: '90') }

      it 'config has a CustomDuration klazz' do
        expect(worker.config.klazz).to eq(FormDurations::CustomDuration)
      end

      it 'config static is false' do
        expect(worker.config.static).to be(false)
      end

      it 'has a duration of 90 days' do
        expect(worker.get_duration).to eq(90.days)
      end
    end

    context 'when dynamic form with no expiration days' do
      let(:worker) { subject.build(form_id: 'HC-QSTNR_abc123', days_till_expires: '') }

      it 'config has a CustomDuration klazz' do
        expect(worker.config.klazz).to eq(FormDurations::CustomDuration)
      end

      it 'has a duration of 60 days' do
        expect(worker.get_duration).to eq(60.days)
      end
    end
  end
end
