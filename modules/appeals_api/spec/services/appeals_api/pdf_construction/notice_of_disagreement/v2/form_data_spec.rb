# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::FormData do
  let(:notice_of_disagreement) { create(:notice_of_disagreement_v2, :board_review_hearing) }
  let(:signing_appellant) { notice_of_disagreement.signing_appellant }
  let(:form_data) { described_class.new(notice_of_disagreement) }

  describe '#preferred_phone' do
    it { expect(form_data.preferred_phone).to eq '555-800-1111' }
  end

  describe '#preferred_email' do
    it { expect(form_data.preferred_email).to eq 'clause@north.com' }
  end

  describe '#mailing_address' do
    it { expect(form_data.mailing_address).to eq '123 Main St, North Pole, 00000, CA' }
  end

  describe '#veteran_homeless' do
    it { expect(form_data.veteran_homeless).to eq 'Off' }
  end

  describe '#direct_review' do
    it { expect(form_data.direct_review).to eq 'Off' }
  end

  describe '#evidence_submission' do
    it { expect(form_data.evidence_submission).to eq 1 }
  end

  describe '#hearing' do
    it { expect(form_data.hearing).to eq 'Off' }
  end

  describe '#additional_pages' do
    it { expect(form_data.additional_pages).to eq 'Off' }
  end

  describe '#rep_name' do
    it { expect(form_data.rep_name).to eq 'Tony Danza' }
  end

  describe '#signature' do
    it { expect(form_data.signature).to eq "Jäñe Doe\n- Signed by digital authentication to api.va.gov" }
  end

  describe '#date_signed' do
    let(:date) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%m/%d/%Y') }

    it { expect(form_data.date_signed).to eq date }
  end

  context 'when delegating to notice of disagreement' do
    describe '#appellant_local_time' do
      it do
        expect(notice_of_disagreement).to receive(:appellant_local_time)
        form_data.appellant_local_time
      end
    end

    describe '#board_review_value' do
      it do
        expect(notice_of_disagreement).to receive(:board_review_value)
        form_data.board_review_value
      end
    end

    describe '#contestable_issues' do
      it do
        expect(notice_of_disagreement).to receive(:contestable_issues)
        form_data.contestable_issues
      end
    end

    describe '#requesting_extension?' do
      it do
        expect(notice_of_disagreement).to receive(:requesting_extension?)
        form_data.requesting_extension?
      end
    end

    describe '#extension_reason' do
      it do
        expect(notice_of_disagreement).to receive(:extension_reason)
        form_data.extension_reason
      end
    end

    describe '#hearing_type_preference' do
      it do
        expect(notice_of_disagreement).to receive(:hearing_type_preference)
        form_data.hearing_type_preference
      end
    end

    describe '#appealing_vha_denial?' do
      it do
        expect(notice_of_disagreement).to receive(:appealing_vha_denial?)
        form_data.appealing_vha_denial?
      end
    end

    describe '#signing_appellant' do
      it do
        expect(notice_of_disagreement).to receive(:signing_appellant)
        form_data.signing_appellant
      end
    end

    describe '#veteran' do
      it do
        expect(notice_of_disagreement).to receive(:veteran)
        form_data.veteran
      end
    end

    describe '#claimant' do
      it do
        expect(notice_of_disagreement).to receive(:claimant)
        form_data.claimant
      end
    end

    describe '#representative' do
      it do
        expect(notice_of_disagreement).to receive(:representative)
        form_data.representative
      end
    end
  end
end
