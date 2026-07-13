:On Error exit
:r .\00_admin\000_reset_database.sql
:r .\00_admin\002_create_schemas.sql
:r .\00_admin\003_create_etl_control_tables.sql
:r .\01_raw\101_create_raw_tables.sql
:r .\02_staging\201_create_staging_tables.sql
:r .\03_dw\301_create_dimensions.sql
:r .\03_dw\302_create_facts.sql
:r .\02_staging\202_create_parse_functions.sql
:r .\03_dw\303_load_date_dimension.sql
:r .\03_dw\304_seed_master_dimensions.sql
:r .\02_staging\203_create_stage_procedures.sql
:r .\03_dw\305_create_load_procedures.sql
:r .\04_marts\501_create_contract_monthly_base.sql
:r .\05_orchestration\701_create_batch_orchestration.sql
