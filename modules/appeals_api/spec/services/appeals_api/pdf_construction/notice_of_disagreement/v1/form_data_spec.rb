# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::NoticeOfDisagreement::V1::FormData do
  let(:notice_of_disagreement) { create(:notice_of_disagreement, :board_review_hearing) }
  let(:form_data) { described_class.new(notice_of_disagreement) }

  describe '#veteran_name' do
    it { expect(form_data.veteran_name).to eq('Jäñe Z. Doe') }
  end

  describe '#veteran_ssn' do
    it { expect(form_data.veteran_ssn).to eq('123456789') }
  end

  describe '#veteran_file_number' do
    it { expect(form_data.veteran_file_number).to eq('987654321') }
  end

  describe '#veteran_dob' do
    it { expect(form_data.veteran_dob).to eq('1969-12-31') }
  end

  describe '#mailing_address' do
    it do
      expect(form_data.mailing_address)
        .to eq('123 Main St Suite #1200 Box 4, North Pole, H0H 0H0, Canada')
    end
  end

  describe '#homeless' do
    context 'when true' do
      before { notice_of_disagreement.form_data['data']['attributes']['veteran']['homeless'] = true }

      it { expect(form_data.homeless).to eq(1) }
    end

    context 'when false' do
      before { notice_of_disagreement.form_data['data']['attributes']['veteran']['homeless'] = false }

      it { expect(form_data.homeless).to eq('Off') }
    end
  end

  describe '#preferred_phone' do
    it { expect(form_data.preferred_phone).to eq('+6-555-800-1111 ext2') }
  end

  describe '#preferred_email' do
    before do
      # Email from fixture file is very long, so set up something shorter here
      notice_of_disagreement.form_data['data']['attributes']['veteran']['emailAddressText'] = 'user@example.com'
    end

    it { expect(form_data.preferred_email).to eq('user@example.com') }
  end

  describe '#direct_review' do
    it { expect(form_data.direct_review).to eq('Off') }
  end

  describe '#evidence_submission' do
    it { expect(form_data.evidence_submission).to eq('Off') }
  end

  describe '#hearing' do
    it { expect(form_data.hearing).to eq(1) }
  end

  describe '#extra_contestable_issues' do
    it { expect(form_data.extra_contestable_issues).to eq(1) }
  end

  describe '#soc_opt_in' do
    it { expect(form_data.soc_opt_in).to eq('Off') }
  end

  describe '#signature' do
    let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement) }

    it { expect(form_data.signature).to eq("Jane Doe\n- Signed by digital authentication to api.va.gov") }

    it 'truncates the signature if name is too long' do
      full_first_name = Faker::Lorem.characters(number: 99)
      notice_of_disagreement.auth_headers['X-VA-First-Name'] = full_first_name
      full_last_name = Faker::Lorem.characters(number: 99)
      notice_of_disagreement.auth_headers['X-VA-Last-Name'] = full_last_name

      full_name = form_data.veteran_name
      expect(form_data.signature).to eq(
        "#{full_name[0...180]}\n- Signed by digital authentication to api.va.gov"
      )
    end
  end

  describe '#date_signed' do
    it "retrieves the time based on the veteran's Time zone" do
      timezone = notice_of_disagreement
                 .form_data&.dig('data', 'attributes', 'timezone')
                 .presence&.strip || 'UTC'
      todays_date = Time.now.in_time_zone(timezone).strftime('%Y-%m-%d')
      expect(form_data.date_signed).to eq(todays_date)
    end
  end

  describe '#contestable_issues' do
    it { expect(form_data.contestable_issues).to eq(notice_of_disagreement.form_data['included']) }
  end

  describe '#representative_name' do
    it { expect(form_data.representative_name).to eq(notice_of_disagreement.representative_name) }
  end
end
