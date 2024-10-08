# frozen_string_literal: true

require 'claims_api/special_issue_mappers/evss'

module ClaimsApi
  module SpecialIssueMappers
    class Bgs < ClaimsApi::SpecialIssueMappers::Evss
      protected

      def items # rubocop:disable Metrics/MethodLength
        ([
          { name: 'PTSD/1', code: 'PTSD/1' },
          { name: 'PTSD/2', code: 'PTSD/2' },
          { name: 'PTSD/3', code: 'PTSD/3' },
          { name: 'PTSD/4', code: 'PTSD/4' },
          { name: 'PTSD - Combat', code: 'PTSD/1' },
          { name: 'PTSD - Non-Combat', code: 'PTSD/2' },
          { name: 'PTSD - Personal Trauma', code: 'PTSD/3' },
          { name: 'Non-PTSD Personal Trauma', code: 'PTSD/4' },
          { name: '38 USC 1151', code: '38USC1151' },
          { name: 'ABA Election', code: 'AE' },
          { name: 'Abandoned VDC Claim', code: 'AVC' },
          { name: 'AMC NOD Brokering Project', code: 'ANBP' },
          { name: 'Administrative Decision Review - Level 1', code: 'ADRL1' },
          { name: 'Administrative Decision Review - Level 2', code: 'ADRL2' },
          { name: 'Agent Orange - Vietnam', code: 'AOIV' },
          { name: 'Agent Orange - outside Vietnam or unknown', code: 'AOOV' },
          { name: 'AMA SOC/SSOC Opt-In', code: 'ASSOI' },
          { name: 'Annual Eligibility Report', code: 'ELIGIBILITY' },
          { name: 'Asbestos', code: 'ASB' },
          { name: 'AutoEstablish', code: 'AE1' },
          { name: 'Automated Drill Pay Adjustment', code: 'ACTRES' },
          { name: 'Automated Return to Active Duty', code: 'ARAD' },
          { name: 'BDD – Excluded', code: 'BE' },
          { name: 'Brokered - D1BC', code: 'BRKD1BC' },
          { name: 'Brokered - Internal', code: 'BRKINT' },
          { name: 'Burn Pit Exposure', code: 'BPE' },
          { name: 'C-123', code: 'C123' },
          { name: 'COWC', code: 'COWC' },
          { name: 'Character of Discharge', code: 'CD' },
          { name: 'Challenge', code: 'CHE' },
          { name: 'ChemBio', code: 'CB' },
          { name: 'Claimant Service Verification Accepted', code: 'CDOSV' },
          { name: 'Combat Related Death', code: 'CRD' },
          { name: 'Compensation Service Review – AO Outside RVN & Ship', code: 'CSRAQRS' },
          { name: 'Compensation Service Review - Equitable Relief', code: 'CSRER' },
          { name: 'Compensation Service Review - Extraschedular', code: 'CSRE' },
          { name: 'Compensation Service Review – MG/CBRNE/Shad', code: 'CSRMCS' },
          { name: 'Compensation Service Review - Opinion', code: 'CSRO' },
          { name: 'Compensation Service Review - Over $25K', code: 'CSRO25' },
          { name: 'Compensation Service Review - POW', code: 'CSRP' },
          { name: 'Compensation Service Review - Radiation', code: 'CSRR' },
          { name: 'Decision Ready Claim', code: 'DRCI' },
          { name: 'Decision Ready Claim - Deferred', code: 'DRCD' },
          { name: 'Decision Ready Claim - Partial Deferred', code: 'DRCPD' },
          { name: 'Disability Benefits Questionnaire - Private', code: 'DBQP' },
          { name: 'Disability Benefits Questionnaire - VA', code: 'DBQV' },
          { name: 'DRC – Exam Review Complete Approved', code: 'DRCEXRCA' },
          { name: 'DRC – Exam Review Complete Disapproved', code: 'DRCEXRCD' },
          { name: 'DRC – Pending File Scan', code: 'DPFS' },
          { name: 'DRC – Vendor Exam Recommendation', code: 'DRCVENEXRCMD' },
          { name: 'DTA Error – Exam/MO', code: 'DEEM' },
          { name: 'DTA Error – Fed Recs', code: 'DFR' },
          { name: 'DTA Error – Other Recs', code: 'DOR' },
          { name: 'DTA Error – PMRs', code: 'DEP' },
          { name: 'Emergency Care – CH17 Determination', code: 'ECCD' },
          { name: 'Enhanced Disability Severance Pay', code: 'EDSP' },
          { name: 'Environmental Hazard - Camp Lejeune', code: 'EHCL' },
          { name: 'Environmental Hazard – Camp Lejeune – Louisville', code: 'EHCLLOU' },
          { name: 'Environmental Hazard in Gulf War', code: 'GW' },
          { name: 'Extra-Schedular 3.321(b)(1)', code: 'ES3' },
          { name: 'Extra-Schedular IU 4.16(b)', code: 'ESI4' },
          { name: 'FDC Excluded - Additional Claim Submitted', code: 'FEACS' },
          { name: 'FDC Excluded - All Required Items Not Submitted', code: 'FEARINS' },
          { name: 'FDC Excluded - Appeal Pending', code: 'FEAP' },
          { name: 'FDC Excluded - Appeal submitted', code: 'FEAS' },
          { name: 'FDC Excluded - Claim Pending', code: 'FECP' },
          { name: 'FDC Excluded - Claimant Declined FDC Processing', code: 'FDCCFP' },
          { name: 'FDC Excluded - Evidence Received After FDC CEST', code: 'FDCEFC' },
          { name: 'FDC Excluded - FDC Certification Incomplete', code: 'FEFCI' },
          { name: 'FDC Excluded - FTR to Examination', code: 'FEFTE' },
          { name: 'FDC Excluded - Necessary Form(s) not Submitted', code: 'FENS' },
          { name: 'FDC Excluded - Needs Non-Fed Evidence Development', code: 'FDCNED' },
          { name: 'FDC Excluded - requires INDPT VRFCTN of FTI', code: 'FERIVF' },
          { name: 'Fed Record Delay - No Further Dev', code: 'FRDNFD' },
          { name: 'Force Majeure', code: 'FM' },
          { name: 'Fully Developed Claim', code: 'FDC' },
          { name: 'Gulf War Presumptive', code: 'GWP' },
          { name: 'HIV', code: 'HIV' },
          { name: 'Hospital Adjustment Action Plan FY 18/19', code: 'HA' },
          { name: 'IDES Deferral', code: 'ID' },
          { name: 'JSRRC Request', code: 'JSSRCRQST' },
          { name: 'Local Hearing', code: 'LH' },
          { name: 'Local Mentor Review', code: 'LMR' },
          { name: 'Local Quality Review', code: 'LQR' },
          { name: 'Local Quality Review IPR', code: 'LQRIPR' },
          { name: 'Medical Foster Home', code: 'MFH' },
          { name: 'MQAS Separation and Severance Pay Audit', code: 'MSSPA' },
          { name: 'Mustard Gas', code: 'MG' },
          { name: 'National Quality Review', code: 'NATNLQUALREV' },
          { name: 'Nehmer AO Peripheral Neuropathy', code: 'NAPN' },
          { name: 'Nehmer Phase II', code: 'NP' },
          { name: 'Non-ADL Notification Letter', code: 'NANL' },
          { name: 'Non-Nehmer AO Peripheral Neuropathy', code: 'NNAPN' },
          { name: 'Potential Under/Overpayment', code: 'PUO' },
          { name: 'RO Special issue 1', code: 'ROSI1' },
          { name: 'RO Special issue 2', code: 'ROSI2' },
          { name: 'RO Special Issue 3', code: 'ROSPISTHR' },
          { name: 'RO Special Issue 4', code: 'ROSPISFOR' },
          { name: 'RO Special Issue 5', code: 'RSI5' },
          { name: 'RO Special Issue 6', code: 'RSI6' },
          { name: 'RO Special Issue 7', code: 'RSI7' },
          { name: 'RO Special Issue 8', code: 'RSI8' },
          { name: 'RO Special Issue 9', code: 'RSI9' },
          { name: 'RVSR Examination', code: 'REN' },
          { name: 'Radiation', code: 'RDN' },
          { name: 'Radiation Radiogenic Disability Confirmed', code: 'RRDC' },
          { name: 'Rating Decision Review - Level 1', code: 'RDR1' },
          { name: 'Rating Decision Review - Level 2', code: 'RDR2' },
          { name: 'Ready for Exam', code: 'RFE' },
          { name: 'Same Station Review', code: 'SSR' },
          { name: 'SHAD', code: 'SHAD' },
          { name: 'Sarcoidosis', code: 'SARCO' },
          { name: 'Simultaneous Award Adjustment Not Permitted', code: 'SAANP' },
          { name: 'Specialized Records Request', code: 'SPECRECRQST' },
          { name: 'Stage 1 Development', code: 'S1D' },
          { name: 'Stage 2 Development', code: 'S2D' },
          { name: 'Stage 3 Development', code: 'S3D' },
          { name: 'TBI Exam Review', code: 'TER' },
          { name: 'Temp 100 Convalescence', code: 'TMC' },
          { name: 'Temp 100 Hospitalization', code: 'T1H' },
          { name: 'Tobacco', code: 'TOB' },
          { name: 'Tort Claim', code: 'TC' },
          { name: 'Traumatic Brain Injury', code: 'TBI' },
          { name: 'Upfront Verification', code: 'UV' },
          { name: 'VACO Special issue 1', code: 'COSI1' },
          { name: 'VACO Special issue 2', code: 'COSI2' },
          { name: 'VACO Special Issue 3', code: 'VACSPISTHR' },
          { name: 'VACO Special Issue 4', code: 'VACSPISFOR' },
          { name: 'VACO Special Issue 5', code: 'VACSPIS5' },
          { name: 'VACO Special Issue 6', code: 'VACSPIS6' },
          { name: 'VACO Special Issue 7', code: 'VACSPIS7' },
          { name: 'VACO Special Issue 8', code: 'VACSPIS8' },
          { name: 'VACO Special Issue 9', code: 'VACSPIS9' },
          { name: 'VASRD-Cardiovascular', code: 'VC' },
          { name: 'VASRD-Dental', code: 'VD' },
          { name: 'VASRD-Digestive', code: 'VRD' },
          { name: 'VASRD-Endocrine', code: 'VEN' },
          { name: 'VASRD-Eye', code: 'VE' },
          { name: 'VASRD-GU', code: 'VG' },
          { name: 'VASRD-GYN', code: 'VDG' },
          { name: 'VASRD-Hemic', code: 'VH' },
          { name: 'VASRD-Infectious', code: 'VI' },
          { name: 'VASRD-Mental', code: 'VML' },
          { name: 'VASRD-Musculoskeletal', code: 'VM' },
          { name: 'VASRD-Neurological', code: 'VN' },
          { name: 'VASRD-Respiratory/Auditory', code: 'VRA' },
          { name: 'VASRD-Skin', code: 'VS' },
          { name: 'Vendor Exclusion - No Diagnosis', code: 'VEXCLNODIAG' },
          { name: 'VONAPP Direct Connect', code: 'VDC' },
          { name: 'WARTAC', code: 'WARTAC' },
          { name: 'WARTAC Trainee', code: 'WT' }
        ] + super).uniq { |special_issue| special_issue[:name] }.freeze
      end
    end
  end
end
