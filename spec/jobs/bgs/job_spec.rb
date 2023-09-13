# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::Job, type: :job do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }

  describe '#in_progress_form_copy' do
    it 'returns nil if the in progress form is blank' do
      job = described_class.new

      in_progress_form = job.in_progress_form_copy(nil)
      expect(in_progress_form).to eq(nil)
    end

    it 'returns an object with metadata and formdata' do
      in_progress_form = InProgressForm.new(form_id: '686C-674',
                                            user_uuid: user.uuid,
                                            form_data: all_flows_payload,
                                            user_account: user.user_account)
      job = described_class.new

      in_progress_form_copy = job.in_progress_form_copy(in_progress_form)
      expect(in_progress_form_copy.meta_data['expiresAt']).to be_truthy
    end
  end

  describe '#salvage_save_in_progress_form' do
    let!(:user_verification) { create(:user_verification, idme_uuid: user.idme_uuid) }

    it 'returns nil if the in progress form is blank' do
      job = described_class.new

      in_progress_form = job.salvage_save_in_progress_form('686C-674', user.uuid, nil)
      expect(in_progress_form).to eq(nil)
    end

    it 'upserts an InProgressForm' do
      in_progress_form = InProgressForm.create!(form_id: '686C-674',
                                                user_uuid: user.uuid,
                                                form_data: all_flows_payload,
                                                user_account: user.user_account)
      job = described_class.new

      in_progress_form = job.salvage_save_in_progress_form('686C-674', user.uuid, in_progress_form)
      expect(in_progress_form).to eq(true)
    end
  end

  describe '#normalize_names_and_addresses!(hash)' do
    it 'removes non-ASCII characters from name and address values in given hash, modifying the hash in-place' do
      # rubocop:disable Layout/LineLength
      raw_string = "Téśt'-Strïñg/1`"
      normalized_name_string = 'Test-String/'
      normalized_address_string = "Test'-String/1"

      # Should modify name fields
      all_flows_payload['veteran_information']['full_name']['first'] = raw_string
      all_flows_payload['veteran_information']['full_name']['middle'] = raw_string
      all_flows_payload['veteran_information']['full_name']['last'] = raw_string

      # Should modify name fields deeper in the hash
      all_flows_payload['dependents_application']['report_divorce']['full_name']['first'] = raw_string
      all_flows_payload['dependents_application']['report_divorce']['full_name']['middle'] = raw_string
      all_flows_payload['dependents_application']['report_divorce']['full_name']['last'] = raw_string

      # Should modify address_line fields
      all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line1'] = raw_string
      all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line2'] = raw_string
      all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line3'] = raw_string

      # Should modify fields, even within arrays of hashes
      all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line1'] = raw_string
      all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line2'] = raw_string
      all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line3'] = raw_string

      # Should modify fields within arrays of hashes, beyond the first element in such arrays
      all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['first'] = raw_string
      all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['middle'] = raw_string
      all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['last'] = raw_string

      # Should not modify other fields with similar names to the name and address fields that should be modified (e.g. should not modify country_name, email_address, etc.)
      all_flows_payload['dependents_application']['veteran_contact_information']['email_address'] = raw_string
      all_flows_payload['dependents_application']['last_term_school_information']['address']['country_name'] = raw_string

      BGS::Job.new.normalize_names_and_addresses!(all_flows_payload)

      expect(all_flows_payload['veteran_information']['full_name']['first']).to eq(normalized_name_string)
      expect(all_flows_payload['veteran_information']['full_name']['middle']).to eq(normalized_name_string)
      expect(all_flows_payload['veteran_information']['full_name']['last']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['report_divorce']['full_name']['first']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['report_divorce']['full_name']['middle']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['report_divorce']['full_name']['last']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line1']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line2']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['last_term_school_information']['address']['address_line3']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line1']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line2']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][0]['child_address_info']['address']['address_line3']).to eq(normalized_address_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['first']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['middle']).to eq(normalized_name_string)
      expect(all_flows_payload['dependents_application']['children_to_add'][1]['full_name']['last']).to eq(normalized_name_string)

      expect(all_flows_payload['dependents_application']['veteran_contact_information']['email_address']).to eq(raw_string)
      expect(all_flows_payload['dependents_application']['last_term_school_information']['address']['country_name']).to eq(raw_string)
      # rubocop:enable Layout/LineLength
    end
  end
end
