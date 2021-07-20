# frozen_string_literal: true

require 'lighthouse/facilities/client'

module PCAFC
  class Facilities
    STATION_NUMBERS = %w[vha_402 vha_405 vha_436 vha_437 vha_438 vha_442
                         vha_459 vha_460 vha_463 vha_501 vha_502 vha_503
                         vha_504 vha_506 vha_508 vha_509 vha_512 vha_515
                         vha_516 vha_517 vha_518 vha_519 vha_520 vha_521
                         vha_523 vha_526 vha_528 vha_528A5 vha_528A6
                         vha_528A7 vha_528A8 vha_529 vha_531 vha_534
                         vha_537 vha_538 vha_539 vha_540 vha_541 vha_542
                         vha_544 vha_546 vha_548 vha_549 vha_550 vha_552
                         vha_553 vha_554 vha_556 vha_557 vha_558 vha_561
                         vha_562 vha_564 vha_565 vha_568 vha_568A4 vha_570
                         vha_573 vha_575 vha_578 vha_580 vha_581 vha_583
                         vha_585 vha_586 vha_589 vha_589A4 vha_589A5
                         vha_589A6 vha_589A7 vha_590 vha_593 vha_595
                         vha_596 vha_598 vha_600 vha_603 vha_605 vha_607
                         vha_608 vha_610 vha_612A4 vha_613 vha_614 vha_618
                         vha_619 vha_620 vha_621 vha_623 vha_626 vha_629
                         vha_630 vha_631 vha_632 vha_635 vha_636 vha_636A6
                         vha_636A8 vha_637 vha_640 vha_642 vha_644 vha_646
                         vha_648 vha_649 vha_650 vha_652 vha_653 vha_654
                         vha_655 vha_656 vha_657 vha_657A4 vha_657A5 vha_658
                         vha_659 vha_660 vha_662 vha_663 vha_664 vha_666
                         vha_667 vha_668 vha_671 vha_672 vha_673 vha_674
                         vha_675 vha_676 vha_678 vha_679 vha_687 vha_688
                         vha_689 vha_691 vha_692 vha_693 vha_695 vha_740
                         vha_756 vha_757].freeze

    def self.all
      get_facilities
    end

    def self.search_params
      {
        ids: PCAFC::Facilities::STATION_NUMBERS.join(','),
        per_page: 200 # There are currently 142 PCAFC facilities (all listed above)
      }
    end

    def self.get_facilities
      lighthouse.get_facilities(search_params)
    end

    def self.lighthouse
      Lighthouse::Facilities::Client.new
    end

    def self.return_facility_label(target_facility_code)
      caregiver_facilities = if Flipper.enabled?(:ezcg_use_facility_api)
                               filter_facility_response(get_facilities)
                                 .sort_by { |hsh| hsh[:code] }
                             else
                               VetsJsonSchema::CONSTANTS['caregiverProgramFacilities']
                                 .values.flatten.sort_by { |hsh| hsh[:code] }
                             end

      selected_facility = caregiver_facilities.find { |facility| facility['code'] == target_facility_code }
      selected_facility.nil? ? nil : "#{selected_facility['code']} - #{selected_facility['label']}"
    end

    def self.filter_facility_response(response)
      response.collect { |facility| { 'code' => facility.unique_id, 'label' => facility.name } }
    end
  end
end
