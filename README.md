# ShopSmart Retail Data Warehouse

A comprehensive, cloud-based data warehouse and ETL pipeline project designed to integrate, transform, and analyze multi-source retail data for actionable business insights.

## Project Overview
The **ShopSmart Retail Data Warehouse** project consolidates disparate retail data into a centralized, optimized analytical repository. The system integrates seven core source datasets—online sales, store sales, customers, products, stores, inventory, and promotions—into a unified dimensional data model.

## Key Features & Architecture

* **Staging Layer & ETL Transformations:** Developed custom SQL ETL routines to extract source data, standardize text, dates, and product codes, resolve duplicates, and handle missing attributes (mapping missing values to explicit dimension members like *Unknown Customer* and *No Promotion*).
* **Data Quality Management:** Conducted thorough data profiling to identify issues such as missing IDs, duplicate transactions, mixed date formats, and inconsistent text, paired with documented treatment rules and data mappings.
* **Dimensional Modelling (Star Schema):** Designed an optimized star schema featuring:
  * A sales transaction fact table.
  * A daily inventory snapshot fact table.
  * Standardized date, product, customer, store, and promotion dimension tables utilizing surrogate keys and defined grain.
* **Data Validation & Reconciliation:** Performed row-count checks, sales aggregations, foreign key validations, and duplicate key scans to ensure strict data integrity.
* **Advanced Analytics:** Wrote over 15 complex analytical SQL queries to uncover sales trends, evaluate product and store performance, segment customers, analyze promotional effectiveness, and monitor stock risk.

## Tech Stack
* **Cloud & Database Tools:** AWS, DBeaver, Microsoft SQL Server / PostgreSQL
* **Languages & Concepts:** SQL, ETL Design, Star Schema, Dimensional Modelling, Data Profiling, Data Reconciliation

## SQL Analytics & Reporting
The repository includes production-ready analytical scripts targeting key business areas:
* Revenue and sales trend analysis over time.
* Product and store performance tracking.
* Customer purchasing behavior and segmentation.
* Promotional impact assessment and stock risk evaluation.
