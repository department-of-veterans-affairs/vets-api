# frozen_string_literal: true

require 'rails_helper'

describe DependentsVerificationsSerializer, type: :serializer do
  subject { serialize(dependent_verifications, serializer_class: described_class) }

  let(:dependent_verifications) { build_stubbed(:dependent_verifications) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  describe 'dependency_verifications' do
    context 'when dependency_decs is a hash' do
      let(:dependency_decs) { build(:dependency_dec) }
      let(:dependent_verifications) { build(:dependent_verifications, dependency_decs:) }

      it 'includes :dependency_dec as an array' do
        expect(attributes['dependency_verifications'].size).to eq 1
      end
    end

    context 'when dependency_decs is an array' do
      let(:dependency_decs) { build_list(:dependency_dec, 2) }
      let(:dependent_verifications) { build(:dependent_verifications, dependency_decs:) }

      it 'includes :dependency_dec' do
        expect(attributes['dependency_verifications'].size).to eq dependency_decs.size
      end
    end

    it 'does not include :social_sercurity_number' do
      expect(attributes['dependency_verifications'].first).not_to include(:social_security_number)
    end
  end

  describe 'prompt_renewal' do
    context 'when there are multiple entries in the diaries call' do
      let(:dependent_verifications) { build(:dependent_verifications, :multiple_entries) }

      it "returns true when at least one has a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within 7 years" do
        expect(attributes['prompt_renewal']).to be true
      end
    end

    context 'when there is one entry in the diaries call' do
      let(:dependent_verifications) { build(:dependent_verifications) }

      it "returns true when it has a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within 7 years" do
        expect(attributes['prompt_renewal']).to be true
      end

      context 'and the due_date is in the future' do
        let(:cassette_due_date) { Time.zone.parse('2014-05-01T00:00:00-05:00') }

        before { Timecop.freeze(cassette_due_date - time_jump) }

        after { Timecop.return }

        context 'by 6 years and 11 months' do
          let(:time_jump) { 6.years + 11.months }
          let(:dependent_verifications) { build(:dependent_verifications) }

          it 'returns true when the diary_entry is due less than 7 years from now' do
            expect(attributes['prompt_renewal']).to be true
          end
        end

        context 'by 7 years and 1 day' do
          let(:time_jump) { 7.years + 1.day }
          let(:dependent_verifications) { build(:dependent_verifications, :due_in_7_years_1_day) }

          it 'returns false when the diary_entry is due more than 7 years from now' do
            expect(attributes['prompt_renewal']).to be false
          end
        end
      end
    end

    context 'when there are no entries in the diaries call' do
      let(:dependent_verifications) { build(:dependent_verifications, :no_entries) }

      it 'returns false' do
        expect(attributes['prompt_renewal']).to be false
      end
    end

    context "when the entry has a status of 'CXCL'" do
      let(:dependent_verifications) { build(:dependent_verifications, :status_type_cxcl) }

      it 'returns false' do
        expect(attributes['prompt_renewal']).to be false
      end
    end
  end
end
