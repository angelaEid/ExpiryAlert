# COE 418 verification

Verified on November 27, 2026, in the Windows Desktop ExpiryAlert workspace.

## Existing database and Flask on port 5001

- Before writes, O'Brien Basil was linked to Fresh Foods Supplier. Purchase #3, line #4, ordered 10.00 kg at 3.00 per kg. Batch #7 at Hamra contained the only 7.00 kg receipt, leaving 3.00 kg unreceived. Batch #7 had no usage, waste, or alert history. The earlier over-receipt rejection was reported by the project owner and reproduced on the isolated instance below.
- Stock Activity recorded simulated usage of 2.00 kg as movement #3, reducing the balance to 5.00 kg. Waste record #2 discarded 1.00 kg with the reason “Expired (COE 418 workflow verification)”, leaving 4.00 kg. MariaDB stored an estimated loss of 3.0000.
- Generating alerts produced pending Expired alert #9 for batch #7. Acknowledgment persisted. Another same-day refresh left exactly one Basil alert, still acknowledged. Alert generation refreshes all eligible stock.
- Home, Inventory, Products, Purchases, Expiration Alerts, Reports, and the batch activity page returned HTTP 200.

## Isolated clean install

- Started a separate loopback MariaDB 12.3 instance with a fresh data directory and port. Installed scripts 01–07 in order using the isolated installer account and generated application and reader passwords.
- Script 06 returned 1 after COMMIT and 1 after ROLLBACK. The seeded purchase #1 total was 270.0000. The committed insert persisted, and rollback restored the temporary row after the attempted deletion. The purchase, receipt, movement, and waste routines group related writes into transactions with rollback handlers. InnoDB provides transactional durability and row locks serialize competing changes to the same purchase line or batch.
- The reporting reader could query the waste view and was denied access to the purchase totals view after REVOKE. The application account could read inventory and was denied direct updates to remaining quantity.
- Flask returned HTTP 200 for nine pages, including Add Batch and Edit Batch. Missing and invalid form tokens returned HTTP 400. A valid token allowed the workflow.
- Created O'Brien Basil, linked it to the supplier, purchased 10 kg at 3 per kg, received 7 kg, and confirmed a second receipt for 4 kg was rejected. The batch remained at 7 kg after rejection. Usage and waste reduced it to 4.00 kg with a loss of 3.0000. Generating, acknowledging, and refreshing the alert preserved one acknowledgment. The apostrophe in the product name worked in both creation and inventory search using bound parameters.

## Rubric evidence

| Rubric item | Evidence |
| --- | --- |
| Schema and sample data | Scripts 01 and 02 define 14 tables. The original clean-install run seeded 34 rows. The expanded seed adds nine sample rows across branches, employees, suppliers, supplier-product links, and storage. |
| Joins and set operations | Script 03 queries 1–5 cover inner, outer, self join, grouped filtering, and UNION. |
| Subqueries | Script 03 queries 6–10 cover nested IN, a correlated average, NOT IN, EXISTS, and division through double NOT EXISTS. |
| Views and routines | Scripts 04 and 05 install four views, three triggers, six procedures, and one function. |
| Indexes | The branch/date composite index supports branch equality with a date range. The batch expiration and waste disposal indexes support date-range filters. Script 06 includes EXPLAIN examples. The optimizer may scan the small seeded tables. |
| Transactions and security | Scripts 06 and 07 provide the commit/rollback and grants evidence described above. For the injection discussion, explain why placing a name inside manually quoted SQL can break on an apostrophe, then show the working parameterized search and its result. |
| Application | Use the observed live and isolated results above in the report's evaluation. Alert generation and acknowledgment are in-app operations. |
| ERD and logical model | The available file named ERD project.pdf describes a wardrobe system. Obtain the Group 10 ExpiryAlert ERD, verify keys, cardinalities and participation against script 01, and include the relational model with a 3NF/BCNF justification. |
| Report and presentation | Prepare the 3–5 page report in the course's single-column IEEE template. Include the problem and information needs, design decisions, expert SQL and application tests, results, and conclusion. Gather author names, team roles, citations, and actual AI disclosure. Plan the 20-minute presentation and demo so every member presents and can answer questions. |

The handout calls for one team ZIP with the IEEE PDF, presentation, numbered SQL scripts, application source, and README. Add the team's approved design and presentation materials before packaging.
