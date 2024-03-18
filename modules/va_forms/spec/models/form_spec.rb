# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAForms::Form, type: :model do
  describe 'callbacks' do
    it 'sets the last_revision to the first issued date if blank' do
      form = VAForms::Form.new
      form.form_name = '526ez'
      form.url = 'https://va.gov/va_form/21-526ez.pdf'
      form.title = 'Disability Compensation'
      form.first_issued_on = Time.zone.today - 1.day
      form.pages = 2
      form.sha256 = 'somelongsha'
      form.valid_pdf = true
      form.row_id = 4909
      form.save
      form.reload
      expect(form.last_revision_on).to eq(form.first_issued_on)
    end

    describe '#set_sha256_history' do
      let(:form) { create(:va_form) }
      let(:new_sha256) { '68b6d817881be1a1c8f323a9073a343b81d1c5a6e03067f27fe595db77645c22' }

      context 'when the sha256 has changed' do
        it 'updates the last_sha256_change and change_history' do
          form.sha256 = new_sha256
          form.save!

          current_date = Time.zone.today
          new_history = { 'sha256' => new_sha256, 'revision_on' => current_date.strftime('%Y-%m-%d') }

          expect(form.reload.last_sha256_change).to eq(current_date)
          expect(form.reload.change_history['versions']).to include(new_history)
        end
      end

      context 'when the sha256 has not changed' do
        it 'does not update the last_sha256_change or change_history' do
          last_sha256_change = form.last_sha256_change
          change_history = form.change_history

          form.title = 'A new title'
          form.save

          expect(form.reload.last_sha256_change).to eq(last_sha256_change)
          expect(form.reload.change_history).to eq(change_history)
        end
      end
    end
  end

  describe '.normalized_form_url' do
    context 'when the url starts with http' do
      let(:starting_url) { 'http://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf' }
      let(:ending_url) { 'https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf' }

      it 'returns the url with http replaced with https' do
        expect(described_class.normalized_form_url(starting_url)).to eq(ending_url)
      end
    end

    context 'when the url does not start with http' do
      let(:starting_url) { './medical/pdf/vha10-10171-fill.pdf' }
      let(:ending_url) { 'https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf' }

      it 'calls the expanded_va_url method' do
        expect(described_class).to receive(:expanded_va_url).with(starting_url).and_return(ending_url)
        described_class.normalized_form_url(starting_url)
      end
    end

    it 'returns the encoded url' do
      starting_url = 'https://www.va.gov/vaforms/medical/pdf/VHA 10-10171 (Fill).pdf'
      ending_url = 'https://www.va.gov/vaforms/medical/pdf/VHA%2010-10171%20(Fill).pdf'

      expect(described_class.normalized_form_url(starting_url)).to eq(ending_url)
    end
  end

  describe '.expanded_va_url' do
    context 'when the url starts with ./medical' do
      let(:starting_url) { './medical/pdf/vha10-10171-fill.pdf' }
      let(:ending_url) { 'https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf' }

      it 'returns the expanded url' do
        expect(described_class.expanded_va_url(starting_url)).to eq(ending_url)
      end
    end

    context 'when the url starts with ./va' do
      let(:starting_url) { './va/pdf/10182-fill.pdf' }
      let(:ending_url) { 'https://www.va.gov/vaforms/va/pdf/10182-fill.pdf' }

      it 'returns the expanded url' do
        expect(described_class.expanded_va_url(starting_url)).to eq(ending_url)
      end
    end

    context 'when the url does not start with ./medical or ./va' do
      let(:starting_url) { './pdf/10182-fill.pdf' }

      it 'raises an ArgumentError' do
        expect { described_class.expanded_va_url(starting_url) }.to raise_error(ArgumentError)
      end
    end
  end
end
