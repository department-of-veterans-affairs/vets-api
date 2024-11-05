# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::NextStepsEmailData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:email_address) }
    it { expect(subject).to validate_presence_of(:first_name) }
    it { expect(subject).to validate_presence_of(:form_name) }
    it { expect(subject).to validate_presence_of(:form_number) }
    it { expect(subject).to validate_presence_of(:representative_type) }

    it {
      expect(subject).to validate_inclusion_of(:representative_type)
        .in_array(AccreditedIndividual.individual_types.keys)
    }

    it { expect(subject).to validate_presence_of(:representative_name) }
    it { expect(subject).to validate_presence_of(:representative_address) }
  end

  describe '#representative_type_humanized' do
    it 'returns the humanized and titleized version of the representative type' do
      next_steps_email_data = described_class.new(representative_type: 'claims_agent')
      expect(next_steps_email_data.representative_type_humanized).to eq('Claims Agent')
    end
  end
end
