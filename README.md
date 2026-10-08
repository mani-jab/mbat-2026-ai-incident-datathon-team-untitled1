# Generative AI Risks & Safeguards  
## MBAT × SEC Victoria Datathon 2026

**Finalist Project | Team Untitled1**

This project was developed for the **MBAT Club Datathon 2026**, a competition for postgraduate students focused on solving a real-world problem involving generative AI risk and governance for **SEC Victoria**.

Our team analysed the **AI Incident Database (AIID)** to identify recurring generative AI failure patterns, quantify how frequently they appeared across distinct incidents, and translate those findings into practical safeguards for potential use of generative AI across SEC Victoria's retail, wholesale and household-electrification operations.

---

## Team

**Team Untitled1**

- Lingesh Ravivarman
- Mani Jabbari
- Joshua Bannon
- Somya Verma

Our team was selected as a **finalist** and presented our findings to the judging panel.

---

## Project Objective

The analysis focused on four questions:

1. What failure patterns repeatedly appear in reported generative AI incidents?
2. How common are these patterns across distinct incidents?
3. Which risks are most relevant to SEC Victoria's proposed internal generative AI use cases?
4. What practical safeguards are supported by the incident evidence?

A key methodological decision was to perform the main risk analysis at the **incident level rather than the report level**, reducing the influence of highly publicised incidents that were covered by many different reports.

---

## Technical Approach

The project combines **MongoDB, R, text mining and reproducible Quarto reporting**.

The workflow included:

- connecting to the AI Incident Database through **MongoDB Atlas**;
- validating identifiers, dates, missing values and source coverage;
- joining the `reports` and `incidents` collections using MongoDB aggregation pipelines;
- validating report-to-incident relationships and duplicate behaviour;
- cleaning and preparing unstructured article text;
- identifying a reproducible generative AI incident population;
- tokenisation and exploratory text analysis;
- word-frequency and phrase analysis;
- **TF-IDF** to identify distinctive language across incidents;
- rule-based classification of recurring generative AI failure patterns;
- incident-level prevalence analysis;
- mapping quantified risks to SEC Victoria use cases; and
- translating the findings into a risk-tiered safeguard framework.

The database workflow was designed to perform filtering, joining and summarisation server-side where practical before transferring results into R for further analysis.

---

## Key Findings

The analysis identified seven recurring generative AI risk categories:

1. **Incorrect or fabricated outputs**
2. **Fraud or impersonation**
3. **Privacy or confidential-data exposure**
4. **Security or misuse**
5. **Bias or discrimination**
6. **Unsafe or harmful advice**
7. **Automation or oversight failures**

Reporting intensity varied substantially between incidents, reinforcing the importance of measuring prevalence using **distinct incidents rather than raw report counts**.

The findings supported a **layered, risk-tiered approach** to generative AI adoption. Higher-consequence applications require stronger verification, human oversight, access controls, data governance and monitoring than lower-risk applications such as drafting or summarisation.

---

## Project Structure

```text
mbat-2026-ai-incident-datathon-team-untitled1/
│
├── README.md
├── _quarto.yml
├── .gitignore
│
├── docs/
│   ├── report.qmd
│   └── slides.qmd
│
├── src/
│   ├── validation_pipeline.R
│   └── load_validation_data.R
│
├── data/
│   └── validation/
│       ├── README.md
│       ├── summary.json
│       ├── date_audit.csv
│       ├── domain_summary.csv
│       ├── join_audit.csv
│       ├── cleaning_audit.csv
│       └── validation_checks.csv
│
└── outputs/
    ├── report.html
    ├── report.pdf
    ├── slides.html
    ├── report_files/
    └── slides_files/
```

### `docs/`

Contains the Quarto source documents used for the final report and presentation.

- `report.qmd` — complete analysis and written report
- `slides.qmd` — finalist presentation source

### `src/`

Contains supporting R code used for extraction and validation.

- `validation_pipeline.R` — MongoDB extraction, validation, joining and text-cleaning pipeline
- `load_validation_data.R` — loads and verifies the derived validation evidence used by the report

### `data/validation/`

Contains small derived validation and summary outputs generated during the original analysis.

These include:

- publication-date validation;
- source-domain summaries;
- report-to-incident join checks;
- text-cleaning audits; and
- validation checks.

Raw AIID article text and MongoDB credentials are not included.

### `outputs/`

Contains the rendered competition deliverables:

- `report.html`
- `report.pdf`
- `slides.html`

The accompanying `report_files/` and `slides_files/` directories contain the assets required by the rendered HTML documents.

---

## Tools Used

### Data Analysis

- R
- tidyverse
- dplyr
- tidyr
- ggplot2

### Text Analysis

- tidytext
- textclean
- TF-IDF
- tokenisation
- n-gram analysis
- rule-based text classification

### Data Engineering

- MongoDB Atlas
- mongolite
- MongoDB aggregation pipelines
- JSON / BSON
- server-side filtering and joins

### Reporting & Visualisation

- Quarto
- Plotly
- reveal.js
- HTML / PDF reporting

The original pipeline uses environment variables rather than embedding MongoDB credentials directly in source code.

---

## Important Limitations

The results should be interpreted as evidence about **reported AI incidents**, not the overall failure rate of deployed generative AI systems.

Key limitations include:

- **Selection bias:** AIID contains reported incidents involving alleged harm or near-harm and is not a random sample of all AI deployments.
- **Reporting intensity:** some incidents receive substantially more media coverage than others.
- **Generative AI identification:** the reproducible screening approach may miss incidents where generative AI involvement is not clearly described.
- **Text-based classification:** failure categories are reproducible indicators derived from incident text, not definitive causal labels.
- **Language coverage:** the text dictionaries are primarily English-focused.
- **TF-IDF interpretation:** high TF-IDF values identify distinctive language but do not necessarily indicate greater risk severity or prevalence.
- **Source and contributor effects:** repeated sources or submitters may influence observed reporting patterns.
- **Database activity:** some publication patterns may partially reflect bulk ingestion or database updates rather than independent incident activity.

---

## Repository Note

The original competition MongoDB Atlas instance is no longer available, so the database extraction cannot currently be rerun.

The original competition deliverables are preserved in `outputs/`, including the rendered **HTML report, PDF report and presentation slides**.