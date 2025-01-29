# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData do
  describe '#new_evidence_locations' do
    let(:supplemental_claim) { build(:extra_supplemental_claim) }
    let(:form_data) { described_class.new(supplemental_claim) }

    it 'returns all the new evidence locations (with upload evidence indicated)' do
      evidence_locations = ['X-Ray VAMC', 'Blood Lab VA Facility',
                            "Doctor's Notes VAMC", 'CT scan VA Medical Facility',
                            'Lab work VAMC',
                            'Veteran indicated they will send evidence documents to VA.']
      expect(form_data.new_evidence_locations).to eq(evidence_locations)
    end

    it 'returns all the new evidence locations (without upload evidence indicated)' do
      # manually setting this to simulate a submission without upload indicated
      supplemental_claim.evidence_submission_indicated = false

      evidence_locations = ['X-Ray VAMC', 'Blood Lab VA Facility',
                            "Doctor's Notes VAMC", 'CT scan VA Medical Facility',
                            'Lab work VAMC']
      expect(form_data.new_evidence_locations).to eq(evidence_locations)
    end
  end

  describe '#new_evidence_dates' do
    let(:supplemental_claim) { build(:extra_supplemental_claim) }
    let(:form_data) { described_class.new(supplemental_claim) }

    it 'returns all the new evidence dates' do
      evidence_dates = [
        [
          '2020-04-10',
          '2020-01-02 to 2020-02-01',
          '2020-02-20 to 2020-02-22',
          '2019-02-02 to 2020-02-03'
        ],
        [
          '2020-02-20 to 2020-02-22',
          '2020-02-02 to 2020-02-07'
        ],
        ['2020-04-10'],
        [
          '2020-07-19',
          '2018-03-06 to 2019-02-12'
        ],
        %w[2018-03-06 2018-01-15],
        ['']
      ]
      expect(form_data.new_evidence_dates).to eq(evidence_dates)
    end
  end

  describe '#form_5103_notice_acknowledged' do
    context "when benefit_type is not 'compensation'" do
      context "when 'form5103Acknowledged' value supplied" do
        let(:supplemental_claim) { build(:supplemental_claim) }
        let(:form_data) { described_class.new(supplemental_claim) }

        it 'returns a nil value' do
          supplemental_claim.form_data['data']['attributes'].merge({ form5103Acknowledged: true })
          expect(form_data.form_5103_notice_acknowledged).to be_nil
        end
      end

      context "when benefit_type == 'compensation'" do
        let(:supplemental_claim) { build(:extra_supplemental_claim) }
        let(:form_data) { described_class.new(supplemental_claim) }

        context "when 'form5103Acknowledged' == true" do
          it { expect(form_data.form_5103_notice_acknowledged).to eq 1 }
        end

        context "when 'form5103Acknowledged' == false" do
          it do
            supplemental_claim.form_data['data']['attributes']['form5103Acknowledged'] = false
            expect(form_data.form_5103_notice_acknowledged).to eq 'Off'
          end
        end
      end
    end
  end
end
