# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DisabilityCompensation::Form526IncreaseOnly do
  let(:user) { build(:disabilities_compensation_user) }

  before do
    create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
  end

  describe '#to_submission_data' do
    context 'without a 4142 submission' do
      subject { described_class.from_hash(form_content) }

      let(:form_content) do
        JSON.parse(File.read('spec/support/disability_compensation_form/front_end_submission.json'))
      end
      let(:submission_data) do
        JSON.parse(File.read('spec/support/disability_compensation_form/submissions/only_526.json'))
      end

      it 'returns a hash of submission data' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
              expect(JSON.parse(subject.to_submission_data(user))).to eq submission_data
            end
          end
        end
      end
    end
  end
end
