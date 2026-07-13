:On Error exit
USE margem_em_risco;
GO

EXEC etl.usp_process_pending_batches;
GO

:r .\06_tests\602_phase02_data_tests.sql
:r .\03_business_rules\400_phase03_preflight.sql
:r .\03_business_rules\401_create_config_objects.sql
:r .\03_business_rules\402_seed_risk_parameters.sql
:r .\04_marts\502_create_contract_monthly_performance.sql
:r .\04_marts\503_create_margin_loss_bridge.sql
:r .\04_marts\504_create_contract_risk_score.sql
:r .\04_marts\505_create_contract_risk_drivers.sql
:r .\04_marts\506_create_action_priority_queue.sql
:r .\04_marts\507_create_executive_views.sql
:r .\06_tests\603_phase03_business_tests.sql
:r .\07_analysis\702_review_risk_and_actions.sql
