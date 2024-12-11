# frozen_string_literal: true

require 'rails_helper'

# TO-DO: Remove flipper once updated Post-911 SOB released
describe Post911GIBillStatusSerializer, type: :serializer do
  subject { serialize(gi_bill_status, serializer_class: described_class) }

  let(:gi_bill_status) { build(:gi_bill_status_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  shared_examples 'whether flipper enabled or disabled' do
    it 'includes :id' do
      expect(data['id']).to be_blank
    end

    it 'includes :first_name' do
      expect(attributes['first_name']).to eq gi_bill_status.first_name
    end

    it 'includes :last_name' do
      expect(attributes['last_name']).to eq gi_bill_status.last_name
    end

    it 'includes :name_suffix' do
      expect(attributes['name_suffix']).to eq gi_bill_status.name_suffix
    end

    it 'includes :date_of_birth' do
      expect(attributes['date_of_birth']).to eq gi_bill_status.date_of_birth
    end

    it 'includes :va_file_number' do
      expect(attributes['va_file_number']).to eq gi_bill_status.va_file_number
    end

    it 'includes :regional_processing_office' do
      expect(attributes['regional_processing_office']).to eq gi_bill_status.regional_processing_office
    end

    it 'includes :eligibility_date' do
      expect(attributes['eligibility_date']).to eq gi_bill_status.eligibility_date
    end

    it 'includes :delimiting_date' do
      expect(attributes['delimiting_date']).to eq gi_bill_status.delimiting_date
    end

    it 'includes :percentage_benefit' do
      expect(attributes['percentage_benefit']).to eq gi_bill_status.percentage_benefit
    end

    it 'includes :original_entitlement' do
      expect_entitlement(attributes['original_entitlement'], gi_bill_status.original_entitlement)
    end

    it 'includes :used_entitlement' do
      expect_entitlement(attributes['used_entitlement'], gi_bill_status.used_entitlement)
    end

    it 'includes :remaining_entitlement' do
      expect_entitlement(attributes['remaining_entitlement'], gi_bill_status.remaining_entitlement)
    end

    it 'includes :active_duty' do
      expect(attributes['active_duty']).to eq gi_bill_status.active_duty
    end

    it 'includes :veteran_is_eligible' do
      expect(attributes['veteran_is_eligible']).to eq gi_bill_status.veteran_is_eligible
    end

    it 'includes :enrollments' do
      expect(attributes['enrollments'].size).to eq gi_bill_status.enrollments.size
    end

    it 'includes :enrollments with attributes' do
      expected_attributes = gi_bill_status.enrollments.first.attributes.keys.map(&:to_s)
      expect(attributes['enrollments'].first.keys).to eq expected_attributes
    end

    context 'enrollment' do
      let(:enrollment) { attributes['enrollments'].first }

      it 'includes :amendments' do
        expect(enrollment['amendments'].size).to eq gi_bill_status.enrollments.first.amendments.size
      end

      it 'includes :amendments with attributes' do
        expected_attributes = gi_bill_status.enrollments.first.amendments.first.attributes.keys.map(&:to_s)
        expect(enrollment['amendments'].first.keys).to eq expected_attributes
      end
    end
  end

  context 'flipper disabled: :sob_updated_design' do
    before(:all) { Flipper.disable(:sob_updated_design) }

    it_behaves_like 'whether flipper enabled or disabled'

    it 'excludes entitlement_transferred_out' do
      expect(attributes.has_key?('entitlement_transferred_out')).to be false
    end
  end

  context 'flipper enabled: :sob_updated_design' do
    before(:all) { Flipper.enable(:sob_updated_design) }

    it_behaves_like 'whether flipper enabled or disabled'

    it 'includes :entitlement_transferred_out' do
      expect_entitlement(attributes['entitlement_transferred_out'], gi_bill_status.entitlement_transferred_out)
    end
  end

  private

  def expect_entitlement(serialized_entitlement, entitlement)
    expect(serialized_entitlement).to eq(
      'months' => entitlement.months,
      'days' => entitlement.days
    )
  end
end
