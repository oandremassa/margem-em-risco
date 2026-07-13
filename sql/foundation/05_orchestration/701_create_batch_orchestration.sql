USE margem_em_risco;
GO

CREATE OR ALTER PROCEDURE etl.usp_process_pending_batches
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id INT;
    DECLARE @source_name VARCHAR(100);

    DECLARE pending_batches CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            batch_id,
            source_name
        FROM etl.batch_control
        WHERE status = 'RUNNING'
          AND source_name IN
          (
              'contract_register',
              'monthly_measurements',
              'operational_costs',
              'workforce_control',
              'sla_incidents',
              'contract_adjustments'
          )
        ORDER BY
            CASE source_name
                WHEN 'contract_register' THEN 1
                WHEN 'monthly_measurements' THEN 2
                WHEN 'operational_costs' THEN 3
                WHEN 'workforce_control' THEN 4
                WHEN 'sla_incidents' THEN 5
                WHEN 'contract_adjustments' THEN 6
                ELSE 99
            END,
            batch_id;

    OPEN pending_batches;

    FETCH NEXT FROM pending_batches INTO @batch_id, @source_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            IF @source_name = 'contract_register'
            BEGIN
                EXEC etl.usp_stage_contract_batch @batch_id = @batch_id;
                EXEC etl.usp_load_contract_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.contract_register',
                    @staging_table = 'staging.stg_contract';
            END
            ELSE IF @source_name = 'monthly_measurements'
            BEGIN
                EXEC etl.usp_stage_measurement_batch @batch_id = @batch_id;
                EXEC etl.usp_load_revenue_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.monthly_measurements',
                    @staging_table = 'staging.stg_measurement';
            END
            ELSE IF @source_name = 'operational_costs'
            BEGIN
                EXEC etl.usp_stage_cost_batch @batch_id = @batch_id;
                EXEC etl.usp_load_cost_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.operational_costs',
                    @staging_table = 'staging.stg_cost';
            END
            ELSE IF @source_name = 'workforce_control'
            BEGIN
                EXEC etl.usp_stage_operation_batch @batch_id = @batch_id;
                EXEC etl.usp_load_operation_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.workforce_control',
                    @staging_table = 'staging.stg_operation';
            END
            ELSE IF @source_name = 'sla_incidents'
            BEGIN
                EXEC etl.usp_stage_sla_batch @batch_id = @batch_id;
                EXEC etl.usp_load_sla_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.sla_incidents',
                    @staging_table = 'staging.stg_sla_incident';
            END
            ELSE IF @source_name = 'contract_adjustments'
            BEGIN
                EXEC etl.usp_stage_adjustment_batch @batch_id = @batch_id;
                EXEC etl.usp_load_adjustment_batch @batch_id = @batch_id;
                EXEC etl.usp_finish_batch
                    @batch_id = @batch_id,
                    @raw_table = 'raw.contract_adjustments',
                    @staging_table = 'staging.stg_adjustment';
            END;
        END TRY
        BEGIN CATCH
            UPDATE etl.batch_control
            SET
                status = 'FAILED',
                finished_at = SYSDATETIME(),
                error_message = ERROR_MESSAGE()
            WHERE batch_id = @batch_id;

            CLOSE pending_batches;
            DEALLOCATE pending_batches;

            THROW;
        END CATCH;

        FETCH NEXT FROM pending_batches INTO @batch_id, @source_name;
    END;

    CLOSE pending_batches;
    DEALLOCATE pending_batches;
END;
GO
