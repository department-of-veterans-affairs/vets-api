# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/notice_of_disagreement_pdf_options'

describe AppealsApi::NoticeOfDisagreementPdfOptions do
  let(:notice_of_disagreement) { build(:notice_of_disagreement) }
  let(:pdf_options) { described_class.new(notice_of_disagreement) }

  describe '#veteran_name' do
    it { expect(pdf_options.veteran_name).to eq('Jane, Z, Doe') }
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

  describe '#claimant_name' do
    it { expect(pdf_options.claimant_name).to eq('Maria, A, Garcia') }
  end

  describe '#claimant_dob' do
    it { expect(pdf_options.claimant_dob).to eq('1970-01-01') }
  end

  describe '#contact_info' do
    context 'when veteran and claimant contact info is present' do
      it { expect(pdf_options.contact_info).to eq(notice_of_disagreement.veteran_contact_info) }
    end

    context 'when only the claimant info is present' do
      before { notice_of_disagreement.form_data['data']['attributes'].delete('veteran') }

      it { expect(pdf_options.contact_info).to eq(notice_of_disagreement.claimant_contact_info) }
    end

    context 'when only the veteran info is present' do
      before { notice_of_disagreement.form_data['data']['attributes'].delete('claimant') }

      it { expect(pdf_options.contact_info).to eq(notice_of_disagreement.veteran_contact_info) }
    end
  end

  describe '#address' do
    it { expect(pdf_options.address).to eq('123 Main St Suite #1200 Box 4, New York, NY, 30012, United States') }
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

  describe '#phone' do
    it { expect(pdf_options.phone).to eq('+6-555-800-1111 ext2') }
  end

  describe '#email' do
    it { expect(pdf_options.email).to eq('a@a.a') }
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
    context 'when veteran name and claimant name are present' do
      it 'uses the claimant signature' do
        expect(pdf_options.signature).to eq('Maria Garcia')
      end
    end

    context 'when veteran name is present and the claimant name is not' do
      before do
        notice_of_disagreement.auth_headers.delete('X-VA-Claimant-First-Name')
        notice_of_disagreement.auth_headers.delete('X-VA-Claimant-Last-Name')
      end

      it 'uses the veteran signature' do
        expect(pdf_options.signature).to eq('Jane Doe')
      end
    end
  end
end
