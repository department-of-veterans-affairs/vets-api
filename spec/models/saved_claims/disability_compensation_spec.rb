# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DisabilityCompensation::Form526IncreaseOnly do
  let(:user) { build(:disabilities_compensation_user) }

  before do
    create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
  end

  describe '#to_submission_data' do
    context 'without a 4142 submission' do
      let(:form_content) do
        JSON.parse(File.read('spec/support/disability_compensation_form/front_end_submission.json'))
      end
      let(:submission_data) { JSON.parse(File.read('spec/support/disability_compensation_form/saved_claim.json')) }
      subject { described_class.from_hash(form_content) }

      it 'returns a hash of submission data' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
              expect(subject.to_submission_data(user)).to eq submission_data
            end
          end
        end
      end
    end

    context 'with a 4142 submission' do
      let(:form_content_with_4142) do
        JSON.parse(
          File.read('spec/support/disability_compensation_form/front_end_submission_with_4142.json')
        )
      end
      let(:submission_data_with_4142) do
        JSON.parse(File.read('spec/support/disability_compensation_form/saved_claim_with_4142.json'))
      end
      subject { described_class.from_hash(form_content_with_4142) }

      it 'returns a hash of submission data including 4142 and overflow text' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
              expect(subject.to_submission_data(user)).to eq submission_data_with_4142
            end
          end
        end
      end
    end
  end
end
