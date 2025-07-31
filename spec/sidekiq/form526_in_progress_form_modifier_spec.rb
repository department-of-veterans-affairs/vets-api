# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526InProgressFormModifier, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  describe '#validate_ipf_id_array_return_ipfs' do
    let(:modifier) { described_class.new }

    context 'when ipf_id_array is not an array' do
      it 'raises ArgumentError with appropriate message' do
        expect do
          modifier.validate_ipf_id_array_return_ipfs('not_an_array')
        end.to raise_error(ArgumentError, 'ipf_id_array must be an array')
      end
    end

    context 'when ipf_id_array is empty' do
      it 'raises ArgumentError with appropriate message' do
        expect do
          modifier.validate_ipf_id_array_return_ipfs([])
        end.to raise_error(ArgumentError, 'ipf_id_array cannot be empty')
      end
    end

    context 'when no in-progress forms are found' do
      it 'raises ArgumentError with appropriate message' do
        expect do
          modifier.validate_ipf_id_array_return_ipfs([1, 2, 3])
        end.to raise_error(ArgumentError, /No in-progress forms with the form id \(21-526EZ\) found/)
      end
    end

    context 'when forms exist but all have the new return URL' do
      let!(:form1) do
        create(:in_progress_526_form, metadata: { return_url: '/supporting-evidence/private-medical-records-authorize-release' })
      end
      let!(:form2) do
        create(:in_progress_526_form, metadata: { return_url: '/supporting-evidence/private-medical-records-authorize-release' })
      end

      it 'raises ArgumentError when all forms have the new return URL' do
        expect do
          modifier.validate_ipf_id_array_return_ipfs([form1.id, form2.id])
        end.to raise_error(ArgumentError, /No in-progress forms with the form id \(21-526EZ\) found/)
      end
    end

    context 'when valid forms are found' do
      let!(:form1) do
        create(:in_progress_526_form, metadata: { return_url: '/veteran-information' })
      end
      let!(:form2) do
        create(:in_progress_526_form, metadata: { return_url: '/some-other-url' })
      end
      let!(:form_with_new_url) do
        create(:in_progress_526_form, metadata: { return_url: '/supporting-evidence/private-medical-records-authorize-release' })
      end

      it 'returns only forms that do not have the new return URL' do
        result = modifier.validate_ipf_id_array_return_ipfs([form1.id, form2.id, form_with_new_url.id])
        
        expect(result).to contain_exactly(form1, form2)
        expect(result).not_to include(form_with_new_url)
      end
    end

    context 'when forms with different form_id exist' do
      let!(:form526) do
        create(:in_progress_526_form, metadata: { return_url: '/veteran-information' })
      end
      let!(:other_form) do
        create(:in_progress_form, form_id: '22-1990', metadata: { return_url: '/veteran-information' })
      end

      it 'only returns forms with the correct form_id' do
        result = modifier.validate_ipf_id_array_return_ipfs([form526.id, other_form.id])
        
        expect(result).to contain_exactly(form526)
        expect(result).not_to include(other_form)
      end
    end
  end

  describe '#perform' do
    let(:modifier) { described_class.new }

    context 'when forms have patient acknowledgement set to true' do
      let!(:form_with_acknowledgement) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data['view:patient_acknowledgement'] = { 'view:acknowledgement' => true }
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/veteran-information' })
      end

      it 'logs the update information in dry run mode' do
        expect(Rails.logger).to receive(:info).with("Running InProgress forms modifier for 1 forms")
        expect(Rails.logger).to receive(:info).with(
          'Updating return URL for in-progress',
          in_progress_form_id: form_with_acknowledgement.id,
          new_return_url: '/supporting-evidence/private-medical-records-authorize-release',
          old_return_url: '/veteran-information',
          dry_run: true
        )

        modifier.perform([form_with_acknowledgement.id])
      end

      it 'does not actually update the form in dry run mode' do
        original_metadata = form_with_acknowledgement.metadata.dup
        
        modifier.perform([form_with_acknowledgement.id])
        
        form_with_acknowledgement.reload
        expect(form_with_acknowledgement.metadata).to eq(original_metadata)
      end
    end

    context 'when forms do not have patient acknowledgement set to true' do
      let!(:form_without_acknowledgement) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data['view:patient_acknowledgement'] = { 'view:acknowledgement' => false }
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/veteran-information' })
      end

      let!(:form_with_nil_acknowledgement) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data['view:patient_acknowledgement'] = { 'view:acknowledgement' => nil }
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/veteran-information' })
      end

      let!(:form_without_patient_section) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data.delete('view:patient_acknowledgement')
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/veteran-information' })
      end

      it 'logs no update needed for forms without acknowledgement' do
        expect(Rails.logger).to receive(:info).with("Running InProgress forms modifier for 3 forms")
        expect(Rails.logger).to receive(:info).with(
          'No update needed for in-progress form',
          in_progress_form_id: form_without_acknowledgement.id,
          dry_run: true
        )
        expect(Rails.logger).to receive(:info).with(
          'No update needed for in-progress form',
          in_progress_form_id: form_with_nil_acknowledgement.id,
          dry_run: true
        )
        expect(Rails.logger).to receive(:info).with(
          'No update needed for in-progress form',
          in_progress_form_id: form_without_patient_section.id,
          dry_run: true
        )

        modifier.perform([form_without_acknowledgement.id, form_with_nil_acknowledgement.id, form_without_patient_section.id])
      end
    end

    context 'when there are mixed forms' do
      let!(:form_with_acknowledgement) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data['view:patient_acknowledgement'] = { 'view:acknowledgement' => true }
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/veteran-information' })
      end

      let!(:form_without_acknowledgement) do
        form_data = JSON.parse(build(:in_progress_526_form).form_data)
        form_data['view:patient_acknowledgement'] = { 'view:acknowledgement' => false }
        
        create(:in_progress_526_form, 
               form_data: form_data.to_json,
               metadata: { return_url: '/some-other-url' })
      end

      it 'handles both types of forms appropriately' do
        expect(Rails.logger).to receive(:info).with("Running InProgress forms modifier for 2 forms")
        expect(Rails.logger).to receive(:info).with(
          'Updating return URL for in-progress',
          in_progress_form_id: form_with_acknowledgement.id,
          new_return_url: '/supporting-evidence/private-medical-records-authorize-release',
          old_return_url: '/veteran-information',
          dry_run: true
        )
        expect(Rails.logger).to receive(:info).with(
          'No update needed for in-progress form',
          in_progress_form_id: form_without_acknowledgement.id,
          dry_run: true
        )

        modifier.perform([form_with_acknowledgement.id, form_without_acknowledgement.id])
      end
    end

    
    context 'when validation fails' do
      it 'logs the validation error' do
        expect(Rails.logger).to receive(:error).with(
          'Error in InProgress forms modifier',
          in_progress_form_ids: [],
          class: 'Form526InProgressFormModifier',
          message: 'ipf_id_array cannot be empty'
        )

        expect { modifier.perform([]) }.not_to raise_error
      end
    end

    context 'when database error occurs' do
      let!(:form) do
        create(:in_progress_526_form, metadata: { return_url: '/veteran-information' })
      end

      before do
        allow(InProgressForm).to receive(:where).and_raise(StandardError.new('Database connection error'))
      end

      it 'logs the database error' do
        expect(Rails.logger).to receive(:error).with(
          'Error in InProgress forms modifier',
          in_progress_form_ids: [form.id],
          class: 'Form526InProgressFormModifier',
          message: 'Database connection error'
        )

        expect { modifier.perform([form.id]) }.not_to raise_error
      end
    end
  end

  describe 'NEW_RETURN_URL constant' do
    it 'has the correct value' do
      expect(described_class::NEW_RETURN_URL).to eq('/supporting-evidence/private-medical-records-authorize-release')
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'has retry set to false' do
      expect(described_class.sidekiq_options['retry']).to be false
    end
  end
end
