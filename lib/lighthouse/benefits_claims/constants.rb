# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module BenefitsClaims
  module Constants
    CLAIM_TYPE_LANGUAGE_MAP = {
      'Death' => 'expenses related to death or burial'
    }.freeze

    FRIENDLY_DISPLAY_MAPPING = {
      '21-4142/21-4142a' => 'Authorization to disclose information',
      'Employment info needed' => 'Employment information',
      'EFT - Treasury Mandate Notification' => 'Direct deposit information',
      'PTSD - Need stressor details/med evid of stressful incdnt' => 'Details about cause of PTSD',
      'RV1 - Reserve Records Request' => 'Reserve records',
      'Proof of service (DD214, etc.)' => 'Proof of service',
      'PMR Request' => 'Non-VA medical records',
      'PMR Pending' => 'Non-VA medical records',
      'General Records Request (Medical)' => 'Non-VA medical records',
      'DBQ AUDIO Hearing Loss and Tinnitus' => 'Disability exam for hearing',
      'DBQ PSYCH Mental Disorders' => 'Mental health exam',
      'Employer (21-4192)' => 'Employment information',
      'Unemployability - 21-8940 needed and 4192(s) requested' => 'Work status information',
      'Request Service Treatment Records from Veteran' => 'Official service treatment records',
      '21-4142 incomplete - need provider address' => 'Address of non-VA medical provider',
      'Submit buddy statement(s)' => 'Witness or corroboration statements',
      'ASB - tell us where, when, how exposed' => 'Asbestos exposure information',
      'HAIMS STR Request' => 'Service treatment records',
      'Name of disability needed' => 'Name of disability',
      'NG1 - National Guard Records Request' => 'National Guard service treatment records',
      'DBQ RESP Sleep Apnea' => 'Sleep apnea exam',
      'DBQ MUSC Back (thoracolumbar spine)' => 'Back pain exam',
      'DBQ MUSC Knee and Lower Leg' => 'Knee and leg exam',
      'DBQ NEURO Headaches (including migraines)' => 'Headache and migraine exam',
      '21-4142' => 'Authorization to disclose information',
      '21-4142a' => 'Non-VA medical provider information',
      'DBQ PSYCH PTSD initial' => 'PTSD claim exam',
      'SSA medical evidence requested' => 'Medical records from the Social Security Administration',
      'DBQ PSYCH PTSD Review' => 'PTSD claim follow-up exam',
      'Clarification of Claimed Issue' => 'Clarify claimed condition',
      'DBQ GU Male Reproductive Organ' => 'Reproductive health exam',
      'ASB-medical evid of disease (biopsy) needed' => 'Asbestos exposure medical documentation',
      'ASB-tell us specific disability fm asbestos exposure' => 'Disease or disability related to the asbestos exposure'
    }.freeze

    ACTIVITY_DESCRIPTION_MAPPING = {
      '21-4142/21-4142a' => 'We need your permission to request your personal information from a non-VA source,' \
                            ' like a private doctor or hospital.',
      'Employment info needed' => 'We need employment information from your most recent employer.',
      'EFT - Treasury Mandate Notification' => 'We need your direct deposit information in order to pay benefits,' \
                                               ' if awarded.',
      'PTSD - Need stressor details/med evid of stressful incdnt' => 'We need information about the cause of' \
                                                                     ' your posttraumatic stress disorder (PTSD).',
      'RV1 - Reserve Records Request' => 'We’ve requested your reserve records on your behalf. No action is needed.',
      'Proof of service (DD214, etc.)' => 'We’ve requested your proof of service on your behalf. No action is needed.',
      'PMR Request' => 'We’ve requested your non-VA medical records on your behalf. No action is needed.'
    }.freeze

    SHORT_DESCRIPTION_MAPPING = {
      'RV1 - Reserve Records Request' => 'We’ve requested your service records' \
                                         ' or treatment records from your reserve unit.',
      'Proof of service (DD214, etc.)' => 'We’ve requested all your DD Form 214’s' \
                                          ' or other separation papers for all your periods of military service.',
      'Employer (21-4192)' => 'We sent a letter to your last employer to ask about your job and why you left.',
      'PMR Pending' => 'We’ve requested your non-VA medical records from your medical provider.',
      'General Records Request (Medical)' => 'We’ve requested your non-VA medical records from your medical provider.',
      'Unemployability - 21-8940 needed and 4192(s) requested' => 'We need more information about how your' \
                                                                  ' service-connected disabilities prevent' \
                                                                  ' you from working.',
      'Request Service Treatment Records from Veteran' => 'We need certified copies of your service treatment' \
                                                          ' records if you have them.',
      '21-4142 incomplete - need provider address' => 'We need your private physician’s address to' \
                                                      ' request information for your claim.',
      'Submit buddy statement(s)' => 'We need statements from people who know about your condition.',
      'ASB - tell us where, when, how exposed' => 'To process your disability claim for asbestos exposure, we' \
                                                  ' need a bit more information from you.',
      'HAIMS STR Request' => 'We’ve requested your service treatment records from the Department of Defense.',
      'Name of disability needed' => 'We need to know what your disability is and how it’s connected' \
                                     ' to your military service.',
      'DBQ RESP Sleep Apnea' => 'We’ve requested an exam to learn more about your sleep apnea.' \
                                ' The examiner’s office will contact you to schedule this appointment.',
      'DBQ MUSC Back (thoracolumbar spine)' => 'We’ve requested an exam to understand your back condition.' \
                                               ' The examiner’s office will contact you to schedule this appointment.',
      'DBQ MUSC Knee and Lower Leg' => 'We’ve requested an exam for your knee and lower leg.' \
                                       ' The examiner’s office will contact you to schedule this appointment.',
      'DBQ NEURO Headaches (including migraines)' => 'We’ve requested an exam for your headaches. The' \
                                                     ' examiner’s office will contact you to schedule' \
                                                     ' this appointment.',
      '21-4142' => 'We need your permission to request your personal information from a non-VA source,' \
                   ' like a private doctor or hospital.',
      '21-4142a' => 'We need information about where you received treatment so we can request your medical' \
                    ' records from non-VA medical providers.',
      'DBQ PSYCH PTSD initial' => 'We’ve requested an exam related to your PTSD. The examiner’s' \
                                  ' office will contact you to schedule this appointment.',
      'SSA medical evidence requested' => 'We’ve asked the Social Security Administration (SSA) for your medical' \
                                          ' records.',
      'DBQ PSYCH PTSD Review' => 'We’ve requested a follow-up exam related to your PTSD. The examiner’s' \
                                 ' office will contact you to schedule this appointment.',
      'Clarification of Claimed Issue' => 'We need more information or a medical diagnosis for the condition in your' \
                                          ' benefits claim.',
      'DBQ GU Male Reproductive Organ' => 'We’ve requested an exam to understand the condition affecting your' \
                                          ' reproductive health. The examiner’s office will contact you to' \
                                          ' schedule this appointment.',
      'ASB-medical evid of disease (biopsy) needed' => 'We need medical documentation that supports your claim.',
      'NG1 - National Guard Records Request' => 'We’ve asked your National Guard unit for your' \
                                                ' service treatment records.'
    }.freeze

    SUPPORT_ALIASES_MAPPING = {
      '21-4142/21-4142a' => ['21-4142/21-4142a'],
      'Employment info needed' => ['VA Form 21-4192'],
      'EFT - Treasury Mandate Notification' => ['EFT - Treasure Mandate Notification'],
      'PTSD - Need stressor details/med evid of stressful incdnt' => ['VA Form 21-0781',
                                                                      'PTSD - Need stressor details'],
      'RV1 - Reserve Records Request' => ['RV1 - Reserve Records Request'],
      'Proof of service (DD214, etc.)' => ['Proof of Service (DD214, etc.)'],
      'PMR Request' => ['PMR Request', 'General Records Request (Medical)'],
      'General Records Request (Medical)' => ['General Records Request (Medical)', 'PMR Request'],
      'DBQ AUDIO Hearing Loss and Tinnitus' => ['DBQ AUDIO Hearing Loss and Tinnitus'],
      'DBQ PSYCH Mental Disorders' => ['DBQ PSYCH Mental Disorders'],
      'Employer (21-4192)' => ['Employer (21-4192)'],
      'PMR Pending' => ['PMR Pending', 'General Records Request (Medical)'],
      'Unemployability - 21-8940 needed and 4192(s) requested' => ['Unemployability' \
                                                                   ' - 21-8940 needed and 4192(s) requested'],
      'Request Service Treatment Records from Veteran' => ['Request Service Treatment Records from Veteran'],
      '21-4142 incomplete - need provider address' => ['21-4142 incomplete - need provider address'],
      'Submit buddy statement(s)' => ['Submit buddy statement(s)'],
      'ASB - tell us where, when, how exposed' => ['ASB - tell us where, when, how exposed'],
      'HAIMS STR Request' => ['HAIMS STR Request'],
      'Name of disability needed' => ['Name of disability needed'],
      'DBQ RESP Sleep Apnea' => ['DBQ RESP Sleep Apnea'],
      'DBQ MUSC Back (thoracolumbar spine)' => ['DBQ MUSC Back (thoracolumbar spine)'],
      'DBQ MUSC Knee and Lower Leg' => ['DBQ MUSC Knee and Lower Leg'],
      'DBQ NEURO Headaches (including migraines)' => ['DBQ NEURO Headaches (including migraines)'],
      '21-4142' => ['21-4142'],
      '21-4142a' => ['21-4142a'],
      'DBQ PSYCH PTSD initial' => ['DBQ PSYCH PTSD initial'],
      'SSA medical evidence requested' => ['SSA medical evidence requested'],
      'DBQ PSYCH PTSD Review' => ['DBQ PSYCH PTSD Review'],
      'Clarification of Claimed Issue' => ['Clarification of Claimed Issue'],
      'DBQ GU Male Reproductive Organ' => ['DBQ GU Male Reproductive Organ'],
      'ASB-medical evid of disease (biopsy) needed' => ['ASB-medical evid of disease (biopsy) needed'],
      'NG1 - National Guard Records Request' => ['NG1 - National Guard Records Request'],
      'ASB-tell us specific disability fm asbestos exposure' => ['ASB-tell us specific disability fm asbestos exposure']
    }.freeze

    UPLOADER_MAPPING = {
      '21-4142/21-4142a' => true,
      'Employment info needed' => true,
      'EFT - Treasury Mandate Notification' => false,
      'PTSD - Need stressor details/med evid of stressful incdnt' => true,
      'RV1 - Reserve Records Request' => true,
      'Proof of service (DD214, etc.)' => true,
      'PMR Request' => true,
      'General Records Request (Medical)' => true,
      'DBQ AUDIO Hearing Loss and Tinnitus' => false,
      'DBQ PSYCH Mental Disorders' => false,
      'PMR Pending' => true,
      'Employer (21-4192)' => false,
      'Unemployability - 21-8940 needed and 4192(s) requested' => true,
      'Request Service Treatment Records from Veteran' => true,
      '21-4142 incomplete - need provider address' => true,
      'Submit buddy statement(s)' => true,
      'ASB - tell us where, when, how exposed' => true,
      'HAIMS STR Request' => false,
      'Name of disability needed' => true,
      'DBQ RESP Sleep Apnea' => false,
      'DBQ MUSC Back (thoracolumbar spine)' => false,
      'DBQ MUSC Knee and Lower Leg' => false,
      'DBQ NEURO Headaches (including migraines)' => false,
      '21-4142' => true,
      '21-4142a' => true,
      'DBQ PSYCH PTSD initial' => false,
      'SSA medical evidence requested' => false,
      'DBQ PSYCH PTSD Review' => false,
      'Clarification of Claimed Issue' => true,
      'DBQ GU Male Reproductive Organ' => false,
      'ASB-medical evid of disease (biopsy) needed' => true,
      'NG1 - National Guard Records Request' => false,
      'ASB-tell us specific disability fm asbestos exposure' => true
    }.freeze

    # These are evidence requests that should not be displayed to the user when:
    # - `cst_suppress_evidence_requests_website` feature flag is enabled
    # - `cst_suppress_evidence_requests_mobile` feature flag is enabled
    # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/126870
    SUPPRESSED_EVIDENCE_REQUESTS = [
      'Admin Decision',
      'ADMINCOD',
      'Attorney Fee',
      'Attorney Fee Release',
      'Awaiting Upload of Hearing Transcript',
      'Delayed BDD Exam Requests',
      'Exam Request - Processing',
      'Exam Review - Not Performed',
      'Exam Review - Partially Complete',
      'IT Ticket-Exam Control Issue',
      'ND Additional Action Required',
      'Pending Completion of Concurrent EP',
      'Rating Extraschedular Memorandum',
      'Records Research Task',
      'Resolution of Pending Rating EP',
      'RO Research Coordinator Review',
      'Second Signature',
      'Secondary Action Required',
      'Stage 2 Development' # Not currently used by VBMS but will eventually replace `Secondary Action Required`
    ].freeze

    FIRST_PARTY_AS_THIRD_PARTY_OVERRIDES = [
      'PMR Pending',
      'Proof of service (DD214, etc.)',
      'NG1 - National Guard Records Request',
      'VHA Outpatient Treatment Records (10-7131)',
      'HAIMS STR Follow-up',
      'Audit Request'
    ].freeze
  end
end
# rubocop:enable Metrics/ModuleLength
