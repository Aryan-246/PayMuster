# Migration Archive

This directory contains older migrations that were manually archived.

## Reason for Baselining
The database contained applied migrations (20260803000000_public_ids, 20260804000000_add_public_ids, 20260804113731_make_audit_orgid_nullable) whose .sql source files were permanently lost from the Git repository. Because Prisma's local migration history was physically incomplete but the database was fully updated, Prisma blocked new migrations due to drift.

A new baseline was created matching the exact database state to repair the migration history without losing data. 

**NO DATABASE DATA WAS DELETED OR RESET DURING THIS PROCESS.**
