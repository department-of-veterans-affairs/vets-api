# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  let(:notice_of_disagreement) { build(:notice_of_disagreement, form_data: form_data, auth_headers: auth_headers) }

  let(:auth_headers) { default_auth_headers }
  let(:form_data) { default_form_data }

  let(:default_auth_headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:default_form_data) { fixture_as_json 'valid_10182.json' }

  describe '.build' do
    before { notice_of_disagreement.valid? }

    it('has no errors') do
      expect(notice_of_disagreement.errors).to be_empty
    end
  end

  # rubocop:disable Layout/LineLength
  describe 'validations' do
    describe '#validate_hearing_type_selection' do
      context "when board review option 'hearing' selected" do
        context 'when hearing type provided' do
          before do
            notice_of_disagreement.valid?
          end

          it 'does not throw an error' do
            expect(notice_of_disagreement.errors.count).to be 0
          end
        end

        context 'when hearing type missing' do
          before do
            form_data['data']['attributes'].delete('hearingTypePreference')
            notice_of_disagreement.valid?
          end

          it 'throws an error' do
            expect(notice_of_disagreement.errors.count).to be 1
            expect(notice_of_disagreement.errors[:'/data/attributes/hearingTypePreference'][0][:detail]).to eq(
              "If '/data/attributes/boardReviewOption' 'hearing' is selected, '/data/attributes/hearingTypePreference' must also be present"
            )
          end
        end
      end

      context "when board review option 'direct_review' or 'evidence_submission' is selected" do
        let(:form_data) { fixture_as_json 'valid_10182_minimum.json' }

        context 'when hearing type provided' do
          before do
            notice_of_disagreement.form_data['data']['attributes']['hearingTypePreference'] = 'video_conference'
            notice_of_disagreement.valid?
          end

          it 'throws an error' do
            expect(notice_of_disagreement.errors.count).to be 1
            expect(notice_of_disagreement.errors[:'/data/attributes/hearingTypePreference'][0][:detail]).to eq(
              "If '/data/attributes/boardReviewOption' 'direct_review' or 'evidence_submission' is selected, '/data/attributes/hearingTypePreference' must not be selected"
            )
          end
        end
      end
    end
  end
  # rubocop:enable Layout/LineLength

  describe '.date_from_string' do
    context 'when the string is in the correct format' do
      it { expect(described_class.date_from_string('2005-12-24')).to eq(Date.parse('2005-12-24')) }
    end

    context 'when the string is in the incorrect format' do
      it 'returns nil' do
        expect(described_class.date_from_string('200-12-24')).to be_nil
        expect(described_class.date_from_string('12-24-2005')).to be_nil
        expect(described_class.date_from_string('2005')).to be_nil
        expect(described_class.date_from_string('abc')).to be_nil
      end
    end
  end

  describe '#consumer_name' do
    it { expect(notice_of_disagreement.consumer_name).to eq('va.gov') }
  end
end
