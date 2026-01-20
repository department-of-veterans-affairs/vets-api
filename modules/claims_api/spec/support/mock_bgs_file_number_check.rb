# frozen_string_literal: true

def mock_file_number_check
  allow_any_instance_of(ClaimsApi::VeteranFileNumberLookupService)
    .to receive(:check_file_number_exists!).and_return('796104437')
end
