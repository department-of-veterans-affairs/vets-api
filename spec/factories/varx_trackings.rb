FactoryGirl.define do
  factory :tracking, class: VARx::Tracking do
    tracking_number       "01234567890"
    prescription_id       2_719_324
    prescription_number   "2719324"
    prescription_name     "Drug 1 250MG TAB"
    facility_name         "ABC123"
    rx_info_phone_number  "(333)772-1111"
    ndc_number            "12345678910"
    shipped_date          1.week.ago.utc
    delivery_service      "UPS"
  end
end
