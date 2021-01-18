# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/notice_of_disagreement_pdf_options'

describe AppealsApi::NoticeOfDisagreementPdfOptions do
  let(:notice_of_disagreement) { build(:notice_of_disagreement) }
  let(:pdf_options) { described_class.new(notice_of_disagreement) }

  describe '#veteran_name' do
    it { expect(pdf_options.veteran_name).to eq('Jane Z. Doe') }
  end

  describe '#veteran_ssn' do
    it { expect(pdf_options.veteran_ssn).to eq('123456789') }
  end

  describe '#veteran_file_number' do
    it { expect(pdf_options.veteran_file_number).to eq('987654321') }
  end

  describe '#veteran_dob' do
    it { expect(pdf_options.veteran_dob).to eq('1969-12-31') }
  end

  describe '#homeless?' do
    context 'when true' do
      before { notice_of_disagreement.form_data['data']['attributes']['veteran']['homeless'] = true }

      it { expect(pdf_options).to be_homeless }
    end

    context 'when false' do
      before { notice_of_disagreement.form_data['data']['attributes']['veteran']['homeless'] = false }

      it { expect(pdf_options).not_to be_homeless }
    end
  end

  describe '#representatives_name' do
    it { expect(pdf_options.representatives_name).to eq('Tony Danza') }
  end

  describe '#board_review_option' do
    it { expect(pdf_options.board_review_option).to eq('hearing') }
  end

  describe '#contestable_issues' do
    it { expect(pdf_options.contestable_issues).to eq(notice_of_disagreement.form_data.dig('included')) }
  end

  describe '#date_signed' do
    it 'returns the current date in timezone' do
      timezone = notice_of_disagreement.form_data.dig('data', 'attributes', 'timezone')
      expect(pdf_options.date_signed).to eq(Time.now.in_time_zone(timezone).strftime('%Y-%m-%d'))
    end
  end

  describe '#soc_opt_in?' do
    context 'when true' do
      before { notice_of_disagreement.form_data['data']['attributes']['socOptIn'] = true }

      it { expect(pdf_options).to be_soc_opt_in }
    end

    context 'when false' do
      before { notice_of_disagreement.form_data['data']['attributes']['socOptIn'] = false }

      it { expect(pdf_options).not_to be_soc_opt_in }
    end
  end

  describe '#signature' do
    it 'uses the veteran signature' do
      expect(pdf_options.signature).to eq('Jane Doe')
    end
  end
end
