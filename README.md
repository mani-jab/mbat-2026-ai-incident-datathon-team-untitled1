------------------------------------------------------------------------

### Datathon 2026 — Generative AI Risks and Safeguards for SEC Victoria

Team

- Lingesh Ravivarman

- Mani Jabbari

- Joshua Bannon

- Somya Verma

# Project Overview

This project analyses the AI Incident Database (AIID) to identify recurring generative AI failure patterns and assess what those patterns could mean for SEC Victoria if internal generative AI tools were used across retail, wholesale and household-electrification operations.

The analysis focuses on four questions:

- What failure patterns repeatedly appear in generative AI incidents?

- How common are those patterns across distinct incidents?

- Which risks are most relevant to SEC Victoria's proposed internal uses?

- What practical safeguards are supported by the incident evidence?

## Project Structure

- src/ — R scripts and reusable analysis code.

- data/ — Intermediate computed datasets produced during the analysis.

- docs/ — Quarto source files for the report and presentation.

- \_docs/ — Rendered submission files produced from the Quarto documents.

- manual/ — Competition reference material and supporting documentation.

## Submission Materials

The main submission materials are located in docs/ and \_docs/:

- docs/report.qmd — Reproducible Quarto analysis report.

- docs/slides.qmd — Presentation source file.

- \_docs/ — Rendered HTML/PDF report and presentation outputs for submission.

## Analysis Workflow

The report follows this workflow:

1.  Connect to the AIID MongoDB database and inspect the reports and incidents collections.

2.  Check data quality, missing values, identifier uniqueness and reporting intensity.

3.  Join reports to incidents using report_number and validate the relationship.

4.  Build an incident-level generative AI analysis population.

5.  Use text analysis to explore recurring words and phrases.

6.  Classify recurring generative AI failure patterns at incident level.

7.  Map the quantified failure patterns to SEC Victoria's retail, wholesale and household-electrification operations.

8.  Recommend safeguards and a risk-tiered rollout approach.

## Key Findings

The analysis found that reporting intensity varies substantially across incidents, so the main risk analysis uses distinct incidents rather than raw report counts.

Recurring failure patterns in the screened generative AI incident population include:

1.  incorrect or fabricated outputs;

2.  fraud or impersonation;

3.  privacy or confidential-data risks;

4.  security or misuse;

5.  bias or discrimination;

6.  unsafe or harmful advice; and

7.  automation or oversight failures.

The results support a layered and risk-tiered control approach for SEC Victoria. Higher-consequence uses should receive stronger verification, human oversight, data-governance and security controls than low-risk drafting or summarisation tasks.

## Reproducibility

The project is designed to render end-to-end from the Quarto source files.

Before running the analysis:

Ensure R and the required packages are installed.

Add the MongoDB Atlas connection string to .Renviron as MONGO_URI.

Restart R so the environment variable is available.

Run or render the Quarto report from the project root

The analysis uses packages including:

- mongolite

- tidyverse

- tidytext

- ggplot2

- here

Use project-relative paths with here::here() so the workflow remains reproducible across machines.

## Important Limitations

AIID contains reported incidents and is not a random sample of all deployed AI systems. The database is mainly concerned with incidents where AI systems allegedly harmed or nearly harmed people or other entities, so the results reflect reported failures rather than the full range of AI deployments.

The generative AI screen is reproducible but may miss incidents where generative AI is not clearly described.

Failure-pattern indicators are text-based and should be interpreted as reproducible pattern indicators rather than definitive causal labels.

TF-IDF can be influenced by repeated terms within an incident's linked reports, so a high TF-IDF value does not necessarily mean that a term represents a more important or more common risk.

Some periods with unusually high publication counts also contained many records sharing the same modification date and time. This suggests that part of the apparent activity may reflect bulk database updates or ingestion rather than independent publication behaviour.

A relatively small number of submitters appeared repeatedly among highly represented reports. This creates a potential contributor-selection bias, so report volume should not be treated as an independent measure of source strength or incident importance.

Some reports were flagged while providing little or no editor-note context. This limits the ability to determine why those records were flagged and how much weight they should receive.

The text dictionaries are mainly English-focused, so multilingual incidents may be classified less completely.
