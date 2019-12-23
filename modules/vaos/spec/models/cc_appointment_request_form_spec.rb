# frozen_string_literal: true

# frozen_string_literal true

require 'rails_helper'

describe VAOS::CCAppointmentRequestForm, type: :model do
  let(:user) { build(:user, :vaos) }
  subject { build(:cc_appointment_request_form, :creation, user: user) }

  it 'responds to the correct attributes' do
    expect(subject.attributes.keys)
      .to contain_exactly(
        :appointment_request_detail_code,
        :appointment_request_id,
        :appointment_type,
        :assigning_authority,
        :best_timeto_call,
        :city_state,
        :created_date,
        :date,
        :distance_eligible,
        :distance_willing_to_travel,
        :email,
        :facility,
        :has_provider_new_message,
        :has_veteran_new_message,
        :id,
        :last_access_date,
        :last_updated_date,
        :object_type,
        :office_hours,
        :option_date1,
        :option_date2,
        :option_date3,
        :option_time1,
        :option_time2,
        :option_time3,
        :other_purpose_of_visit,
        :patient,
        :patient_id,
        :phone_number,
        :preferred_city,
        :preferred_language,
        :preferred_providers,
        :preferred_state,
        :provider_id,
        :provider_name,
        :provider_seen_appointment_request,
        :purpose_of_visit,
        :requested_phone_call,
        :second_request,
        :second_request_submitted,
        :service,
        :status,
        :surrogate_identifier,
        :system_id,
        :text_messaging_allowed,
        :type_of_care_id,
        :unique_id,
        :visit_type
      )
  end

  it 'has facilities with an array of children' do
    expect(subject.facility).to be_a(Hash)
    expect(subject.facility[:children]).to be_an(Array)
    expect(subject.facility[:children].size).to eq(3)
  end

  it 'has preferred providers as an array' do
    expect(subject.preferred_providers).to be_an(Array)
  end
end
