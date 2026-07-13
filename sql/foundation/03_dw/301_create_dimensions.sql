USE margem_em_risco;
GO

IF OBJECT_ID(N'dw.dim_date', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_date
    (
        date_key             INT NOT NULL,
        full_date            DATE NOT NULL,
        day_number           TINYINT NOT NULL,
        month_number         TINYINT NOT NULL,
        month_name_pt        NVARCHAR(20) NOT NULL,
        quarter_number       TINYINT NOT NULL,
        year_number          SMALLINT NOT NULL,
        year_month           CHAR(7) NOT NULL,
        month_start_date     DATE NOT NULL,
        month_end_date       DATE NOT NULL,
        is_weekend           BIT NOT NULL,

        CONSTRAINT PK_dim_date PRIMARY KEY (date_key),
        CONSTRAINT UQ_dim_date_full_date UNIQUE (full_date)
    );
END;
GO

IF OBJECT_ID(N'dw.dim_client', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_client
    (
        client_key           INT IDENTITY(1,1) NOT NULL,
        client_code          VARCHAR(20) NOT NULL,
        client_name          NVARCHAR(150) NOT NULL,
        business_segment     VARCHAR(50) NOT NULL,
        company_size         VARCHAR(20) NOT NULL,
        head_office_state    CHAR(2) NOT NULL,
        region_name          VARCHAR(20) NOT NULL,
        relationship_start   DATE NOT NULL,
        client_status        VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_client PRIMARY KEY (client_key),
        CONSTRAINT UQ_dim_client_code UNIQUE (client_code),
        CONSTRAINT CK_dim_client_size CHECK (company_size IN ('MEDIUM', 'LARGE')),
        CONSTRAINT CK_dim_client_status CHECK (client_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_unit', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_unit
    (
        unit_key             INT IDENTITY(1,1) NOT NULL,
        unit_code            VARCHAR(20) NOT NULL,
        client_key           INT NOT NULL,
        unit_name            NVARCHAR(150) NOT NULL,
        city_name            NVARCHAR(100) NOT NULL,
        state_code           CHAR(2) NOT NULL,
        region_name          VARCHAR(20) NOT NULL,
        facility_type        VARCHAR(50) NOT NULL,
        approximate_area_m2  DECIMAL(18,2) NULL,
        is_24x7_operation    BIT NOT NULL,
        criticality_level    VARCHAR(20) NOT NULL,
        unit_status          VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_unit PRIMARY KEY (unit_key),
        CONSTRAINT UQ_dim_unit_code UNIQUE (unit_code),
        CONSTRAINT FK_dim_unit_client FOREIGN KEY (client_key) REFERENCES dw.dim_client(client_key),
        CONSTRAINT CK_dim_unit_area CHECK (approximate_area_m2 IS NULL OR approximate_area_m2 > 0),
        CONSTRAINT CK_dim_unit_criticality CHECK
            (criticality_level IN ('STANDARD', 'RELEVANT', 'HIGH', 'ESSENTIAL')),
        CONSTRAINT CK_dim_unit_status CHECK (unit_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_service', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_service
    (
        service_key              INT IDENTITY(1,1) NOT NULL,
        service_code             VARCHAR(20) NOT NULL,
        service_name             NVARCHAR(80) NOT NULL,
        operating_model          VARCHAR(50) NOT NULL,
        labor_intensity          VARCHAR(20) NOT NULL,
        complexity_level         VARCHAR(20) NOT NULL,
        recommended_margin_pct   DECIMAL(9,4) NOT NULL,
        sla_exposure_level       VARCHAR(20) NOT NULL,
        requires_full_coverage   BIT NOT NULL,
        service_status           VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_service PRIMARY KEY (service_key),
        CONSTRAINT UQ_dim_service_code UNIQUE (service_code),
        CONSTRAINT CK_dim_service_margin CHECK (recommended_margin_pct BETWEEN 0 AND 1),
        CONSTRAINT CK_dim_service_status CHECK (service_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_role', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_role
    (
        role_key              INT IDENTITY(1,1) NOT NULL,
        role_code             VARCHAR(20) NOT NULL,
        role_name             NVARCHAR(100) NOT NULL,
        role_group            VARCHAR(50) NOT NULL,
        is_critical_role      BIT NOT NULL,
        role_status           VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_role PRIMARY KEY (role_key),
        CONSTRAINT UQ_dim_role_code UNIQUE (role_code),
        CONSTRAINT CK_dim_role_status CHECK (role_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_manager', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_manager
    (
        manager_key           INT IDENTITY(1,1) NOT NULL,
        manager_code          VARCHAR(20) NOT NULL,
        manager_name          NVARCHAR(100) NOT NULL,
        region_name           VARCHAR(20) NOT NULL,
        start_date            DATE NOT NULL,
        experience_level      VARCHAR(20) NOT NULL,
        manager_status        VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_manager PRIMARY KEY (manager_key),
        CONSTRAINT UQ_dim_manager_code UNIQUE (manager_code),
        CONSTRAINT CK_dim_manager_experience CHECK
            (experience_level IN ('JUNIOR', 'MID', 'SENIOR')),
        CONSTRAINT CK_dim_manager_status CHECK (manager_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_cost_category', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_cost_category
    (
        cost_category_key     INT IDENTITY(1,1) NOT NULL,
        cost_group            NVARCHAR(60) NOT NULL,
        cost_category         NVARCHAR(80) NOT NULL,
        cost_subcategory      NVARCHAR(100) NOT NULL,
        is_labor_cost         BIT NOT NULL,
        is_controllable_cost  BIT NOT NULL,
        category_status       VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_cost_category PRIMARY KEY (cost_category_key),
        CONSTRAINT UQ_dim_cost_category UNIQUE (cost_group, cost_category, cost_subcategory),
        CONSTRAINT CK_dim_cost_category_status CHECK (category_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_incident_type', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_incident_type
    (
        incident_type_key     INT IDENTITY(1,1) NOT NULL,
        incident_category     NVARCHAR(80) NOT NULL,
        incident_subcategory  NVARCHAR(100) NOT NULL,
        root_cause             NVARCHAR(100) NOT NULL,
        default_severity       VARCHAR(20) NOT NULL,
        responsible_area       VARCHAR(50) NOT NULL,
        has_financial_exposure BIT NOT NULL,
        incident_type_status   VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_incident_type PRIMARY KEY (incident_type_key),
        CONSTRAINT UQ_dim_incident_type UNIQUE
            (incident_category, incident_subcategory, root_cause),
        CONSTRAINT CK_dim_incident_default_severity CHECK
            (default_severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
        CONSTRAINT CK_dim_incident_type_status CHECK
            (incident_type_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_action', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_action
    (
        action_key             INT IDENTITY(1,1) NOT NULL,
        action_code            VARCHAR(30) NOT NULL,
        action_name_pt         NVARCHAR(120) NOT NULL,
        action_category        VARCHAR(50) NOT NULL,
        default_owner_area     VARCHAR(50) NOT NULL,
        action_status          VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dim_action PRIMARY KEY (action_key),
        CONSTRAINT UQ_dim_action_code UNIQUE (action_code),
        CONSTRAINT CK_dim_action_status CHECK (action_status IN ('ACTIVE', 'INACTIVE'))
    );
END;
GO

IF OBJECT_ID(N'dw.dim_contract', N'U') IS NULL
BEGIN
    CREATE TABLE dw.dim_contract
    (
        contract_key             INT IDENTITY(1,1) NOT NULL,
        contract_code            VARCHAR(20) NOT NULL,
        client_key               INT NOT NULL,
        manager_key              INT NOT NULL,
        primary_service_key      INT NOT NULL,
        contract_status          VARCHAR(30) NOT NULL,
        billing_model            VARCHAR(30) NOT NULL,
        complexity_level         VARCHAR(20) NOT NULL,
        start_date               DATE NOT NULL,
        end_date                 DATE NULL,
        renewal_date             DATE NULL,
        base_monthly_amount      DECIMAL(18,2) NOT NULL,
        contracted_positions     DECIMAL(10,2) NOT NULL,
        contracted_hours         DECIMAL(18,2) NOT NULL,
        target_margin_pct        DECIMAL(9,4) NOT NULL,
        adjustment_base_month    TINYINT NULL,
        adjustment_index         VARCHAR(30) NULL,
        valid_from               DATE NOT NULL,
        valid_to                 DATE NULL,
        is_current               BIT NOT NULL,
        row_hash                 VARBINARY(32) NOT NULL,

        CONSTRAINT PK_dim_contract PRIMARY KEY (contract_key),
        CONSTRAINT FK_dim_contract_client FOREIGN KEY (client_key) REFERENCES dw.dim_client(client_key),
        CONSTRAINT FK_dim_contract_manager FOREIGN KEY (manager_key) REFERENCES dw.dim_manager(manager_key),
        CONSTRAINT FK_dim_contract_service FOREIGN KEY (primary_service_key) REFERENCES dw.dim_service(service_key),
        CONSTRAINT UQ_dim_contract_version UNIQUE (contract_code, valid_from),
        CONSTRAINT CK_dim_contract_margin CHECK (target_margin_pct BETWEEN 0 AND 1),
        CONSTRAINT CK_dim_contract_positions CHECK (contracted_positions >= 0),
        CONSTRAINT CK_dim_contract_hours CHECK (contracted_hours >= 0),
        CONSTRAINT CK_dim_contract_amount CHECK (base_monthly_amount > 0),
        CONSTRAINT CK_dim_contract_validity CHECK (valid_to IS NULL OR valid_to >= valid_from),
        CONSTRAINT CK_dim_contract_month CHECK
            (adjustment_base_month IS NULL OR adjustment_base_month BETWEEN 1 AND 12)
    );

    CREATE UNIQUE INDEX UX_dim_contract_current
        ON dw.dim_contract(contract_code)
        WHERE is_current = 1;
END;
GO

IF OBJECT_ID(N'dw.bridge_contract_service', N'U') IS NULL
BEGIN
    CREATE TABLE dw.bridge_contract_service
    (
        contract_key            INT NOT NULL,
        service_key             INT NOT NULL,
        revenue_share_pct       DECIMAL(9,4) NOT NULL,
        cost_share_pct          DECIMAL(9,4) NOT NULL,
        is_primary_service      BIT NOT NULL,
        valid_from              DATE NOT NULL,
        valid_to                DATE NULL,

        CONSTRAINT PK_bridge_contract_service PRIMARY KEY
            (contract_key, service_key, valid_from),
        CONSTRAINT FK_bridge_contract_service_contract
            FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_bridge_contract_service_service
            FOREIGN KEY (service_key) REFERENCES dw.dim_service(service_key),
        CONSTRAINT CK_bridge_contract_service_pct CHECK
        (
            revenue_share_pct BETWEEN 0 AND 1
            AND cost_share_pct BETWEEN 0 AND 1
        ),
        CONSTRAINT CK_bridge_contract_service_validity CHECK
            (valid_to IS NULL OR valid_to >= valid_from)
    );
END;
GO
