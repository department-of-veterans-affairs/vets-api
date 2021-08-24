# frozen_string_literal: true

module EMIS
  module Models
    # EMIS military service episode data
    #
    # @!attribute personnel_category_type_code
    #   @return [String] code that represents the personnel category of the
    #     unit.
    #       A => Active Duty
    #       B => Presidential Appointee
    #       C => DoD Civil Service
    #       D => Disabled Veteran
    #       E => DoD Contractor
    #       F => Former Member
    #       H => Medal of Honor
    #       I => Othr Gov Agcy Empl
    #       J => Academy Student
    #       K => NAF DoD Employee
    #       L => Lighthouse Service
    #       M => Non-gov Agcy Pnl
    #       N => National Guard
    #       O => Othr Gov Agcy Cntrct
    #       Q => Reserve Retiree
    #       R => Retired
    #       T => Foreign Military
    #       U => Foreign National
    #       V => Reserve
    #       W => DoD Beneficiary
    #       Y => Civilian Retirees
    # @!attribute begin_date
    #   @return [Date] date when a sponsor's personnel category and organizational
    #     affiliation began.
    # @!attribute end_date
    #   @return [Date] date when the personnel segment terminated.
    # @!attribute termination_reason
    #   @return [Date] code that represents the reason that the personnel segment
    #     terminated.
    #       D => Death while in PNL CAT or ORG
    #       F => Invalid entry into segment
    #       S => Separation fr PNL CAT or ORG
    #       W => N/A
    # @!attribute branch_of_service_code
    #   @return [String] code that represents the user's branch of service. The data is
    #     received daily and monthly from personnel data feeds and from real time
    #     applications which create and update personnel affiliation data within DMDC. The
    #     data is used for personnel reporting and some operational processes, such as
    #     customizations for service like the seal and printing on ID Cards.
    #       1 => Foreign Army
    #       2 => Foreign Navy
    #       3 => Foreign Marine Corps
    #       4 => Foreign Air Force
    #       6 => Foreign Coast Guard
    #       A => Army
    #       C => Coast Guard
    #       D => DoD
    #       F => Air Force
    #       H => Public Health Service
    #       M => Marine Corps
    #       N => Navy
    #       O => NOAA
    #       X => Other
    #       Z => Unknown
    # @!attribute retirement_type_code
    #   @return [String] code that represents the type of
    #     retirement.
    #       A => Mandatory
    #       B => Voluntary
    #       C => Fleet Reserve
    #       D => TDRL
    #       E => PDRL
    #       F => Title III
    #       G => Special Act
    #       H => Philippine Scouts
    # @!attribute personnel_projected_end_date
    #   @return [Date] date when the personnel segment is projected to end.
    # @!attribute personnel_projected_end_date_certainty_code
    #   @return [String] code that represents the certainty of the personnel projected end
    #     date.
    #       E => Date used to set enforced currency
    #       Q => Date is certain
    #       R => Date is estimated
    #       U => No date can be predicted
    #       W => No date is applicable (OBSOLETE)
    # @!attribute discharge_character_of_service_code
    #   @return [String] code that represents discharge character of
    #     service.
    #       A => Honorable
    #       B => Under honorable conditions (general)
    #       D => Bad conduct
    #       E => Under other than honorable conditions
    #       F => Dishonorable
    #       H => Under honorable conditions (absence of a negative report)
    #       J => Honorable for VA Purposes (Administrative use by VA only)
    #       K => Dishonorable for VA Purposes (Administrative use by VA only)
    #       Y => Uncharacterized
    #       Z => Unknown
    # @!attribute honorable_discharge_for_va_purpose_code
    #   @return [String] no documentation available. Possibly same as
    #     discharge_character_of_service_code.
    # @!attribute personnel_status_change_transaction_type_code
    #   @return [String] code that indicates the type of personnel status change
    #     transaction.
    #       111 => Active Duty (active strength) gain
    #       112 => Active Duty (active strength) gain, non-prior service
    #       115 => Active Duty gain, prior service, from reserve duty
    #       117 => AD (active strength) gain, prior service, from RET (elig)
    #       118 => AD (active strength) gain, prior service, delayd reenlistmnt
    #       119 => AD (active strength) gain, prior service, enlst to offcr
    #       120 => AD (active strength) gain, prior service, revers or drop A S
    #       123 => Active Duty (active strength) gain, prior service, other
    #       131 => Active Duty (active strength) loss
    #       132 => Active Duty (active strength) loss, to civil life
    #       135 => Active Duty (active strength) loss, to reserve duty
    #       137 => AD (active strength) loss, to retired (eligible for retired)
    #       138 => Active Duty (active strength) loss, death
    #       139 => AD (active strength) loss, enlisted to officer vice versa
    #       140 => Active Duty (active strength) loss, dropped from A S
    #       143 => Active Duty (active strength) loss, to Academy
    #       151 => Active Duty (active strength) change, immediate reenlistment
    #       152 => Active Duty (active strength) change, extension
    #       211 => Active Duty (reserve strength) gain
    #       212 => Active Duty (reserve strength) gain, non-prior service
    #       215 => AD (reserve strength) gain, prior service, from RSV duty
    #       216 => AD (RSV strength) gain, prior service, from RET (not elig)
    #       217 => AD reserve strength) gain, prior service, from ret (elig)
    #       219 => AD (reserve strength) gain, prior service, enlst to offcr
    #       231 => Active Duty (reserve strength) loss
    #       232 => Active Duty (reserve strength) loss, to civil life
    #       235 => Active Duty (reserve strength) loss, to reserve duty
    #       236 => AD (RES strength) loss, prior service, to retired (not elig)
    #       237 => AD (RES strength) loss, to retired (eligible for retired pay
    #       238 => Active Duty (reserve strength) loss, death
    #       239 => AD reserve strength loss, enlisted to officer or vice versa
    #       241 => AD (reserve strength) loss to another component (non-RET)
    #       242 => AD (reserve strength) loss to another component (retirement)
    #       251 => AD (reserve strength) change, immediate reenlistment
    #       252 => Active Duty (reserve strength) change, extension
    #       311 => Reserve duty gain
    #       312 => Reserve duty gain, non-prior service
    #       313 => RSV duty gain, prior service, from AD (active strength)
    #       314 => RSV duty gain, prior service, from AD (reserve strength)
    #       316 => RSV duty gain, prior service, from RET (eligible for RET pay
    #       317 => RSV duty gain, prior service, from RET (not elig for RET pay
    #       318 => Reserve duty gain, prior service, delayed reenlistment
    #       319 => RSV duty gain, prior service, enlisted to officer vice versa
    #       321 => RSV duty gain, prior service, from another RSV comp(non RET)
    #       322 => RSV duty gain, prior service, from another RSV comp (RET)
    #       323 => Reserve duty gain, prior service, other
    #       331 => Reserve duty loss
    #       332 => Reserve duty loss, to civil life
    #       333 => Reserve duty loss, to active duty (active strength)
    #       334 => Reserve duty loss, to active duty (reserve strength)
    #       335 => Reserve duty loss, to another Reserve branch of service
    #       336 => RSV duty loss, prior service, to retired not eligible
    #       337 => Reserve duty loss, to retired (eligible for retired pay)
    #       338 => Reserve duty loss, death
    #       339 => Reserve duty loss, enlisted to officer or vice versa
    #       341 => Reserve duty loss to another component (non-retirement)
    #       342 => Reserve duty loss to another component (retirement)
    #       343 => Reserve duty loss, to Academy
    #       351 => Reserve duty change, immediate reenlistment
    #       352 => Reserve duty change, extension
    #       361 => Reserve duty transfer, from Selected Reserve
    #       362 => Reserve duty transfer, from Individual Ready Reserve
    #       363 => Reserve duty transfer, from Inactive National Guard
    #       364 => Reserve duty transfer, from Standby Reserve
    #       371 => Reserve or Guard activation loss, from contingency
    #       372 => Reserve or Guard activation loss, from non-contingency
    #       411 => Retired (not eligible for retired pay) gain
    #       434 => RET loss not eligible to AD (reserve strength)
    #       435 => RET (not eligible for retired pay) loss, to reserve duty
    #       436 => RET loss not eligible to eligible for retired pay
    #       999 => Invalid entry
    # @!attribute narrative_reason_for_separation_code
    #   @return [String] narrative reason for the member's separation from the Service. This
    #     data element is used by VA in lieu of the Separation Program Designator Code (
    #     SPD_CD).
    # @!attribute post911_gi_bill_loss_category_code
    #   @return [String] a DMDC derived data element created by grouping the Separation
    #     Program Designator code into categories used by the Department of Veterans Affairs
    #     in determining Post-9/11 GI Bill eligibility. The data is created daily and
    #     monthly. The data is used to update DEERS.
    #       01 => Service connected disability
    #       02 => Disability existed prior to Military Service
    #       03 => Physical or mental condition interfering with perf of duty
    #       04 => Hardship
    #       05 => Reduction in force/Force Shaping
    #       06 => Qualifying Active Duty Period
    #       07 => Disqualifying Active Duty Period
    #       99 => Unknown/Not Applicable
    # @!attribute mgad_loss_category_code
    #   @return [String] a DMDC derived data element created by grouping the Separation
    #     Program Designator code into categories used by the Department of Veterans Affairs
    #     in determining Montgomery GI Bill eligibility. The data is created daily and
    #     monthly from personnel data feeds. The data is used to update DEERS.
    #       00 => Invalid
    #       01 => Service connected disability
    #       02 => Disability existed prior
    #       03 => Physical or mental condition
    #       04 => Hardship
    #       05 => Reduction in force
    #       06 => Convenience of government, Other
    #       07 => Expiration of term of service
    #       08 => Other separation to civil life
    #       09 => Death
    #       10 => Dropped from strength
    #       11 => Immediate reenlistment
    # @!attribute active_duty_service_agreement_quantity
    #   @return [String] numeric value of years of the current active service agreement. The
    #     data is submitted daily and monthly in personnel data feeds. The data is used for
    #     human resources actions and updating DEERS.
    #       00 => 0 Years
    #       01 => 1 Year
    #       02 => 2 Years
    #       03 => 3 Years
    #       04 => 4 Years
    #       05 => 5 Years
    #       06 => 6 Years
    #       07 => 7 Years
    #       08 => 8 Years
    #       99 => Unknown or not applicable
    # @!attribute initial_entry_training_end_date
    #   @return [Date] date for which the member's initial entry training ended. The data is
    #     received daily and monthly from data feeds for employment reporting.
    # @!attribute uniform_service_initial_entry_date
    #   @return [Date] date for which the member was first appointed, enlisted, or
    #     conscripted into a Uniformed Service of the US. Also referred to as Date of Initial
    #     Entry to a Uniformed Service. The data is received daily and monthly from data
    #     feeds for employment reporting.
    # @!attribute military_accession_source_code
    #   @return [String] a DMDC derived data element created from the following three data
    #     elements in the Active Duty and Reserve Submissions: Enlisted Accession Program
    #     Source Code, Commissioned Officer Accession Program Source Code, and Warrant
    #     Officer Accession Program Source Code for reporting. Also referred to as Source of
    #     Initial Appointment. The data is created daily and monthly for employment reporting.
    #       00 => Unknown
    #       01 => Academy graduate
    #       02 => Academy graduate, USMA
    #       03 => Academy graduate, USNA
    #       04 => Academy graduate, USAFA
    #       05 => Academy graduate, USCGA
    #       06 => Academy graduate, USMMA
    #       07 => Academy graduate, ANG AofMS
    #       08 => ROTC/NROTC Scholarship
    #       09 => ROTC/NROTC Non-scholarship
    #       10 => OCS/AOCS/OTS/PLC
    #       11 => Aviation cadet
    #       12 => National Guard State OCS
    #       13 => Direct appointment, professional
    #       14 => Direct appointment, nonprofessional
    #       15 => Aviation Training Program
    #       16 => Voluntary enlistment in Regular component under NCS program
    #       17 => ROTC Scholarship Program under sec 2107(a), 10 USC
    #       21 => Direct appointment, Warrant Officer
    #       22 => Direct appointment, CMSN WO
    #       23 => WO aviation training program
    #       30 => Other (active)
    #       97 => Other (Reserve)
    #       98 => Not applicable (Reserve)
    #       99 => Unknown (Reserve)
    # @!attribute personnel_begin_date_source
    #   @return [String] code that represents the source of the Personnel Begin
    #     Date.
    #       0 => Unknown or not applicable
    #       1 => Default value or corrected using standard logic
    #       2 => Active Duty Military Personnel File: Pay Plan Grade Effective Date
    #       3 => Active Duty Military Personnel File: Enlisted Active Service Agreement Date
    #       4 => Active Duty Military Personnel File: Military Longevity Pay Base Date
    #       5 => Active Duty Military Personnel File: Active Federal Military Service Base Date
    #       6 => Previous instance end date or following instance begin date
    #       7 => MEPCOM Military Personnel File: Enlisted Active Service Agreement Date or other authoritative source
    #       8 => Online/RAPIDS
    #       B => BIRLS - Beneficiary Identification Records Locator Subsystem (Administrative
    #         values used only in VA Satellites)
    #       V => VISTA - Veterans Health Information Systems and Technology Architecture (
    #         Administrative values used only in VA Satellites)
    # @!attribute personnel_termination_date_source_code
    #   @return [String] code that represents the source of the personnel termination date
    #     and the reliability of that date. The higher the number, the greater the
    #     reliability.
    #       0 => not terminated
    #       1 => Date arbitrarily set by DEERS - indicates data problem
    #       2 => Returned as terminated by Core
    #       3 => Terminated by PNL/PNLEC sweep for date in past
    #       4 => Suspense termination moved up by Suspense Sweep
    #       5 => Batch termination from generated loss (file date)
    #       6 => Background term to allow more current segment to be added
    #       7 => Batch termination from transaction loss
    #       8 => Terminated in V Tools
    # @!attribute active_federal_military_service_base_date
    #   @return [Date] date for which DoD Military Service member's creditable Active
    #     Military Service begins. This constructed date functions to indicate a date on
    #     which a DoD Military Service member's creditable active military service begins for
    #     calculating time. Also referred to as Active Duty Base Date and Basic Active
    #     Service Date. The data is the actual or adjusted date from which the amount of
    #     active military service performed is calculated. The data is received daily and
    #     monthly from personnel data feeds. The data is used for reporting time of active
    #     military service and updating DEERS.
    # @!attribute mgsr_service_agreement_duration_year_quantity_code
    #   @return [String] code that represents the length in years of the current Selected
    #     Reserve agreement/service commitment in the context of the MGIB program.
    #       0 => 0 years
    #       1 => 1 year
    #       2 => 2 years
    #       3 => 3 years
    #       4 => 4 years
    #       5 => 5 years
    #       6 => 6 years
    #       7 => 7 years
    #       8 => 8 years
    #       9 => Indefinite
    #       Z => Unknown
    # @!attribute dod_beneficiary_type_code
    #   @return [String] code that indicates the type of DoD
    #     beneficiary.
    #       01 => Unremarried former spouse 20/20/20
    #       02 => Unmarried former spouse 20/20/20
    #       03 => Unremarried former spouse 20/20/15
    #       04 => Unremarried former spouse 20/20/15 (divorced on or after Apr
    #       05 => Unremarried former spouse 20/20/15 (divorced on or after Sep
    #       06 => Unremarried former spouse 10/20/10 (Sponsor was retirement e
    #       07 => Unmarried former spouse 10/20/10 (Sponsor was retirement eli
    #       08 => Transition Compensation (sponsor was not retirement eligible
    #       09 => Transition Compensation Child
    #       10 => 10/20/10 Child (sponsor was retirement eligible)
    #       11 => Unremarried Former Spouse of a Reserve Retiree less than 60
    #       12 => Unremarried Former Spouse of a Reserve Retiree at or older t
    #       13 => Unmarried 20/20/20 Fmr Spouse of a Rsv Retiree less than 60
    #       14 => Unmarried 20/20/20 Fmr Spse of Rsv Retiree at/over age 60
    #       15 => Unrem 20/20/20 Fmr Spse of a NG/Rsv w 20 yr ltr under age 60
    #       16 => Unrem 20/20/20 Fmr Spse of NG/Rsv w 20 yr letter at/over 60
    #       17 => Unm 20/20/20 Fmr Spse of NG/Rsv 20 yr ltr under age 60
    #       18 => Unm 20/20/20 Fmr Spse of NG/Rsv w 20 yr letter at/over 60
    # @!attribute reserve_under_age60_code
    #   @return [String] code that represents whether or not a Reserve Retired member of the
    #     Guard/Reserve is a Gray Area Retiree, meaning a member who served 90 consecutive
    #     days on Active Duty in support of designated operations for the Global War on
    #     Terror (GWOT), who is allowed to retire with pay before his or her 60th birthday.
    #     Defense Finance and Accounting System (DFAS) sets this code, though the code may be
    #     set by presentation of proper documentation by RAPIDS."
    #       N => No
    #       R => RAPIDS
    #       W => Not applicable
    #       Y => Yes
    class MilitaryServiceEpisodeV2
      include Virtus.model

      # Service branch codes
      SERVICE_BRANCHES = {
        'A' => 'Army',
        'C' => 'Coast Guard',
        'D' => 'DoD',
        'F' => 'Air Force',
        'H' => 'Public Health Service',
        'M' => 'Marine Corps',
        'N' => 'Navy',
        'O' => 'NOAA'
      }.freeze

      # Military service branch codes mapped to HCA schema values
      HCA_SERVICE_BRANCHES = {
        'F' => 'air force',
        'A' => 'army',
        'C' => 'coast guard',
        'M' => 'marine corps',
        'N' => 'navy',
        'O' => 'noaa',
        'H' => 'usphs'
      }.freeze

      # Personnel category codes
      PERSONNEL_CATEGORY_TYPE = {
        'A' => 'Regular Active',
        'N' => 'Guard',
        'V' => 'Reserve',
        'Q' => 'Reserve Retiree'
      }.freeze

      attribute :personnel_category_type_code, String
      attribute :personnel_organization_code, String
      attribute :personnel_segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason, String
      attribute :branch_of_service_code, String
      attribute :retirement_type_code, String
      attribute :personnel_projected_end_date, Date
      attribute :personnel_projected_end_date_certainty_code, String
      attribute :discharge_character_of_service_code, String
      attribute :honorable_discharge_for_va_purpose_code, String
      attribute :personnel_status_change_transaction_type_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :narrative_reason_for_separation_txt, String
      attribute :post911_gi_bill_loss_category_code, String
      attribute :mgad_loss_category_code, String
      attribute :active_duty_service_agreement_quantity, String
      attribute :initial_entry_training_end_date, Date
      attribute :uniform_service_initial_entry_date, Date
      attribute :military_accession_source_code, String
      attribute :personnel_begin_date_source, String
      attribute :personnel_termination_date_source_code, String
      attribute :active_federal_military_service_base_date, Date
      attribute :mgsr_service_agreement_duration_year_quantity_code, String
      attribute :dod_beneficiary_type_code, String
      attribute :reserve_under_age60_code, String
      attribute :pay_plan_code, String
      attribute :pay_grade_code, String
      attribute :service_rank_name_code, String
      attribute :service_rank_name_txt, String
      attribute :pay_grade_date, Date

      # Military service branch in HCA schema format
      # @return [String] Military service branch in HCA schema format
      def hca_branch_of_service
        HCA_SERVICE_BRANCHES[branch_of_service_code] || 'other'
      end

      # Human readable military branch of service
      # @return [String] Human readable military branch of service
      def branch_of_service
        SERVICE_BRANCHES[branch_of_service_code]
      end

      # Human readable personnel category type
      # @return [String] Human readable personnel category type
      def personnel_category_type
        PERSONNEL_CATEGORY_TYPE[personnel_category_type_code]
      end
    end
  end
end
