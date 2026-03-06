# ADR-004: Send Structured Data Before IBM Processes PDF

## Context

IBM Mail Automation processes PDFs from Central Mail Portal into VBMS. During processing, IBM queries GCIO for structured JSON data to enhance accuracy. The structured data must be available when IBM queries for it.

**Process timeline**:
1. PDF uploaded to Lighthouse → forwarded to Central Mail Portal
2. IBM fetches PDF from Central Mail Portal (timing varies)
3. IBM queries GCIO for structured data (using Lighthouse UUID)
4. IBM processes PDF into VBMS with structured data

**Problem**: We initially designed to send data after `vbms` status (too late).

## Decision

**Send structured data to GCIO immediately after successful Lighthouse upload** (within seconds, not days).

This ensures data is waiting at GCIO when IBM queries for it, regardless of when IBM processes the PDF.

## Alternatives Considered

**After vbms status**: Rejected - IBM already processed PDF by then  
**Polling for IBM processing**: Rejected - No visibility into IBM timing  
**Before Lighthouse upload**: Rejected - No UUID for correlation  

## Consequences

**Positive**:
- Data ready when IBM needs it
- No dependency on IBM timing
- Works regardless of processing delays

**Negative**:
- Data sent even if IBM never processes (edge case)
- Small window where PDF exists but data doesn't (if GCIO fails)

**Mitigation**: Retry logic handles GCIO failures, monitoring tracks success rates
