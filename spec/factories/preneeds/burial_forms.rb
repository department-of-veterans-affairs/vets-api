# frozen_string_literal: true

FactoryBot.define do
  factory :burial_form, class: 'Preneeds::BurialForm' do
    application_status { 'somewhere' }
    has_currently_buried { '1' }
    sending_code { 'abc' }
    sending_application { 'vets.gov' }

    preneed_attachments do
      [attributes_for(:preneed_attachment_hash), attributes_for(:preneed_attachment_hash)]
    end

    applicant { attributes_for(:applicant) }
    claimant { attributes_for(:claimant) }
    currently_buried_persons { [attributes_for(:currently_buried_person), attributes_for(:currently_buried_person)] }
    veteran { attributes_for(:veteran) }
  end

  factory :burial_form_foreign_address, parent: :burial_form do
    applicant { attributes_for(:applicant_foreign_address) }
    claimant { attributes_for(:claimant_foreign_address) }
    veteran { attributes_for(:veteran_foreign_address) }
  end
end
