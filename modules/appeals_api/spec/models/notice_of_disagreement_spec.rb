# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  let(:auth_headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:form_data) { fixture_as_json 'valid_10182.json' }
  let(:notice_of_disagreement) do
    review_option = form_data['data']['attributes']['boardReviewOption']
    build(:notice_of_disagreement, form_data: form_data, auth_headers: auth_headers, board_review_option: review_option)
  end

  describe '.build' do
    before { notice_of_disagreement.valid? }

    it('has no errors') do
      expect(notice_of_disagreement.errors).to be_empty
    end
  end

  # rubocop:disable Layout/LineLength
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
          expect(notice_of_disagreement.errors.first.attribute).to eq(:'/data/attributes/hearingTypePreference')
          expect(notice_of_disagreement.errors.first.options[:detail]).to eq(
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
          expect(notice_of_disagreement.errors.first.attribute).to eq(:'/data/attributes/hearingTypePreference')
          expect(notice_of_disagreement.errors.first.options[:detail]).to eq(
            "If '/data/attributes/boardReviewOption' 'direct_review' or 'evidence_submission' is selected, '/data/attributes/hearingTypePreference' must not be selected"
          )
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

  describe '#veteran_first_name' do
    it { expect(notice_of_disagreement.veteran_first_name).to eq 'Jane' }
  end

  describe '#veteran_last_name' do
    it { expect(notice_of_disagreement.veteran_last_name).to eq 'Doe' }
  end

  describe '#ssn' do
    it { expect(notice_of_disagreement.ssn).to eq '123456789' }
  end

  describe '#file_number' do
    it { expect(notice_of_disagreement.file_number).to eq '987654321' }
  end

  describe '#consumer_name' do
    it { expect(notice_of_disagreement.consumer_name).to eq 'va.gov' }
  end

  describe '#consumer_id' do
    it { expect(notice_of_disagreement.consumer_id).to eq 'some-guid' }
  end

  describe '#zip_code_5' do
    context 'when address present' do
      before do
        form_data['data']['attributes']['veteran']['address']['zipCode5'] = '30012'
      end

      it { expect(notice_of_disagreement.zip_code_5).to eq '30012' }
    end

    context 'when homeless and no address' do
      before do
        veteran_data = form_data['data']['attributes']['veteran']
        veteran_data['homeless'] = true
        veteran_data.delete('address')
      end

      it { expect(notice_of_disagreement.zip_code_5).to eq '00000' }
    end
  end

  describe '#zip_code_5_or_international_postal_code' do
    it 'returns internationalPostalCode when zip is 0s' do
      expect(notice_of_disagreement.zip_code_5_or_international_postal_code).to eq 'H0H 0H0'
    end

    it 'returns zipCode5 if it is not all 0s' do
      form_data['data']['attributes']['veteran']['address']['zipCode5'] = '30012'
      expect(notice_of_disagreement.zip_code_5_or_international_postal_code).to eq '30012'
    end
  end

  describe '#lob' do
    it { expect(notice_of_disagreement.lob).to eq 'BVA' }
  end

  describe '#board_review_option' do
    it { expect(notice_of_disagreement.board_review_option).to eq 'hearing' }
  end

  describe '#update_status!' do
    it 'error status' do
      notice_of_disagreement.update_status!(status: 'error', code: 'code', detail: 'detail')

      expect(notice_of_disagreement.status).to eq('error')
      expect(notice_of_disagreement.code).to eq('code')
      expect(notice_of_disagreement.detail).to eq('detail')
    end

    it 'other valid status' do
      notice_of_disagreement.update_status!(status: 'success')

      expect(notice_of_disagreement.status).to eq('success')
    end

    it 'invalid status' do
      expect do
        notice_of_disagreement.update_status!(status: 'invalid_status')
      end.to raise_error(ActiveRecord::RecordInvalid,
                         'Validation failed: Status is not included in the list')
    end

    it 'emits an event' do
      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle!)

      notice_of_disagreement.update_status!(status: 'pending')

      expect(handler).to have_received(:handle!)
    end
  end
end
