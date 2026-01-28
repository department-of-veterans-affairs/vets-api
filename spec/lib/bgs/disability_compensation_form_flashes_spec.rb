# frozen_string_literal: true

require 'rails_helper'
require 'bgs/disability_compensation_form_flashes'

Rspec.describe BGS::DisabilityCompensationFormFlashes do
  subject { described_class.new(user, form_content, disabilities) }

  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/submit_all_claim/0781.json')
    )
  end

  let(:flashes) { ['Homeless', 'Priority Processing - Veteran over age 85', 'POW'] }
  let(:disabilities) do
    [
      {
        'name' => 'PTSD (post traumatic stress disorder)',
        'diagnosticCode' => 9999,
        'disabilityActionType' => 'NEW',
        'ratedDisabilityId' => '1100583'
      },
      {
        'name' => 'PTSD personal trauma',
        'disabilityActionType' => 'SECONDARY',
        'serviceRelevance' => "Caused by a service-connected disability\nPTSD (post traumatic stress disorder)"
      }
    ]
  end
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  describe '#translate' do
    it 'returns correctly flashes to send to async job' do
      expect(subject.translate).to eq flashes
    end

    context 'when the user has ALS condition' do
      let(:disabilities) do
        [
          {
            'name' => 'ALS (amyotrophic lateral sclerosis)',
            'disabilityActionType' => 'NEW',
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\ntest"
          }
        ]
      end

      context 'when feature is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:disability_526_ee_process_als_flash, user).and_return(true)
        end

        it 'returns ALS flash' do
          expect(subject.translate).to include('Amyotrophic Lateral Sclerosis')
        end
      end

      context 'when feature is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:disability_526_ee_process_als_flash, user).and_return(false)
        end

        it 'returns without flash' do
          expect(subject.translate).not_to include('Amyotrophic Lateral Sclerosis')
        end
      end
    end
  end
end
