# frozen_string_literal: true

def mock_file_number_check
  allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
    .to receive(:check_file_number_exists!).and_return('796104437')
end
