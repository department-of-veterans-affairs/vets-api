# 2. Initial Research and Findings

Date: 2024-12-10

## Status

Accepted

## Context

After reviewing the BPDS endpoint specs and JSON schema formatting for other BPDS submitted forms, multiple questions and concerns were raised regarding expected format for JSON submissions, obtaining credentials to access the BPDS endpoint, and potential impacts to downstream systems. 

## Decision

Although there were a lot of unknowns, the potential benefits from streamlining the data processing of form submissions was deemed a worthy goal to pursue. Until some of the questions regarding expected JSON schema format were answered, it was decided we would initially work on getting credentials to access the BPDS API.

## Consequences

When fully implemented, this change would completely remove the need for OCR-ing PDF documents mapped with form submission data and substantially reduce the overhead in forms processing. However, with such large process changes, multiple teams will have to be involved, making it difficult to coordinate changes.
