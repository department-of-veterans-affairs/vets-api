# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CaregiversAssistanceClaimsService do
  let(:build_valid_claim_data) { -> { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json } }
  let(:get_schema) { -> { VetsJsonSchema::SCHEMAS['10-10CG'].clone } }

  it 'will raise a ValidationErrors when the provided claim is invalid' do
    user = nil
    invalid_claim_data = { form: {} }

    expect do
      subject.submit_claim!(user, invalid_claim_data)
    end.to raise_error(Common::Exceptions::ValidationErrors)
  end

  it 'will create and return a claim' do
    user = nil
    claim_data = { form: build_valid_claim_data.call }

    result = subject.submit_claim!(user, claim_data)

    expect(result).to be_an_instance_of(SavedClaim::CaregiversAssistanceClaim)
    expect(result.id).to be_truthy
    expect(result.persisted?).to eq(true)
  end

  context 'with user context' do
    it 'will delete the related in progress form, if it exists' do
      user = double(uuid: SecureRandom.uuid)
      claim_data = { form: build_valid_claim_data.call }

      previously_saved_form = build(
        :in_progress_form,
        form_id: '10-10CG',
        form_data: { name: 'kevin' },
        user_uuid: user.uuid
      )

      expect(InProgressForm).to receive(:form_for_user).and_return(previously_saved_form)
      expect(previously_saved_form).to receive(:destroy)

      result = subject.submit_claim!(user, claim_data)

      expect(result).to be_an_instance_of(SavedClaim::CaregiversAssistanceClaim)
      expect(result.id).to be_truthy
      expect(result.persisted?).to eq(true)
    end
  end
end
