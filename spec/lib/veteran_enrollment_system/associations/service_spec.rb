# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/service'

RSpec.describe VeteranEnrollmentSystem::Associations::Service do

  let(:form) { get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact') }
  let(:current_user) do
    create(
      :evss_user,
      :loa3,
      icn: '1012829228V424035',
      birth_date: '1963-07-05',
      first_name: 'FirstName',
      middle_name: 'MiddleName',
      last_name: 'ZZTEST',
      suffix: 'Jr.',
      ssn: '111111234',
      gender: 'F'
    )
  end
  let(:service) { described_class.new(current_user, form) }

  describe '#update_associations' do
    it 'updates the associations' do
      debugger
      # VCR.use_cassette('example', :record => :once) do
        
      # end
     hello = service.update_associations(form)
    end
  end
end