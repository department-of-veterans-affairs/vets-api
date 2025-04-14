# frozen_string_literal: true

FactoryBot.define do
  factory :bpds_submission, class: 'Bpds::Submission' do
    form_id { 'test123' }
    reference_data do
      {
        'id_number' => { 'ssn' => '444444444' },
        'postal_code' => '12345',
        'full_name' => { 'first' => 'First', 'last' => 'Last' },
        'email' => 'a@b.com',
        'form_name' => 'Form Name'
      }.to_json
    end
  end
end
