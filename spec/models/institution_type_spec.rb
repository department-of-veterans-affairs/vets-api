# frozen_string_literal: true
RSpec.describe InstitutionType, type: :model do
  subject { build :institution_type }

  describe 'Sanity Check - InstitutionType' do
    it 'factory is valid' do
      expect(subject).to be_valid
    end

    describe '#name' do
      it 'cannot be blank' do
        expect(build(:institution_type, name: nil)).not_to be_valid
        expect(build(:institution_type, name: '')).not_to be_valid
      end

      it 'is unique' do
        subject.save!
        expect(build(:institution_type, name: subject.name)).not_to be_valid
      end
    end
  end
end
